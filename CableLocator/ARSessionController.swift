import ARKit
import SceneKit
import SwiftUI

final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate, ARSCNViewDelegate {
    enum Mode { case capture, locate }

    let view = ARSCNView(frame: .zero)
    @Published private(set) var status = "Move your phone slowly around the room"
    @Published private(set) var readyToMark = false
    @Published private(set) var relocalized = false
    @Published private(set) var hasLiDAR = false
    @Published private(set) var targetDistance: Float?

    private var mode: Mode = .capture
    private var targetAnchorID: UUID?

    override init() {
        super.init()
        view.session.delegate = self
        view.delegate = self
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func start(mode: Mode, worldMap: ARWorldMap? = nil, targetAnchorID: UUID? = nil) {
        self.mode = mode
        self.targetAnchorID = targetAnchorID
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "This device does not support AR world tracking"
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.vertical, .horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        config.initialWorldMap = worldMap
        relocalized = worldMap == nil
        readyToMark = false
        targetDistance = nil
        status = worldMap == nil ? "Scan the wall and nearby fixed features" : "Scan the original room view to align the saved map"
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() { view.session.pause() }

    func captureMark(completion: @escaping (Result<(ARAnchor, UIImage, ARWorldMap), Error>) -> Void) {
        guard mode == .capture, readyToMark, view.session.currentFrame != nil else {
            completion(.failure(CaptureError.tracking))
            return
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let exactQuery = view.raycastQuery(from: center, allowing: .existingPlaneGeometry, alignment: .any)
        let estimatedQuery = view.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
        let pointTransform = exactQuery.flatMap { view.session.raycast($0).first?.worldTransform }
            ?? estimatedQuery.flatMap { view.session.raycast($0).first?.worldTransform }
        guard let transform = pointTransform else {
            completion(.failure(CaptureError.noSurface))
            return
        }
        let anchor = ARAnchor(name: "cable:mark", transform: transform)
        let photo = view.snapshot()
        view.session.add(anchor: anchor)
        view.session.getCurrentWorldMap { map, error in
            DispatchQueue.main.async {
                guard let map else {
                    completion(.failure(error ?? CaptureError.noMap))
                    return
                }
                if !map.anchors.contains(where: { $0.identifier == anchor.identifier }) {
                    map.anchors.append(anchor)
                }
                completion(.success((anchor, photo, map)))
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let normal: Bool
        switch frame.camera.trackingState {
        case .normal: normal = true
        default: normal = false
        }
        let mapped = frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending
        let isReady = normal && mapped
        let isAligned = normal && (mode == .capture || frame.anchors.contains { $0.identifier == targetAnchorID })
        var distance: Float?
        if let id = targetAnchorID, isAligned,
           let anchor = frame.anchors.first(where: { $0.identifier == id }) {
            let camera = SIMD3<Float>(frame.camera.transform.columns.3.x,
                                      frame.camera.transform.columns.3.y,
                                      frame.camera.transform.columns.3.z)
            let target = SIMD3<Float>(anchor.transform.columns.3.x,
                                      anchor.transform.columns.3.y,
                                      anchor.transform.columns.3.z)
            distance = simd_distance(camera, target)
        }
        DispatchQueue.main.async {
            self.readyToMark = isReady
            self.relocalized = isAligned
            self.targetDistance = distance
            if let id = self.targetAnchorID,
               let anchor = frame.anchors.first(where: { $0.identifier == id }) {
                self.view.node(for: anchor)?.isHidden = !isAligned
            }
            if self.mode == .locate {
                self.status = isAligned ? "Map aligned. Confirm against the photo and measurements" : "Move to the original scan position and scan fixed features"
            } else {
                self.status = isReady ? "Aim the crosshair at the cable end" : "Scan more of the wall and fixed features"
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor.name?.hasPrefix("cable:") == true else { return nil }
        let sphere = SCNSphere(radius: 0.035)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemOrange
        sphere.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: sphere)
        node.isHidden = mode == .locate
        return node
    }

    enum CaptureError: LocalizedError {
        case tracking, noSurface, noMap
        var errorDescription: String? {
            switch self {
            case .tracking: "Keep scanning until tracking is ready."
            case .noSurface: "Aim at the wall or a visible feature next to the cable end."
            case .noMap: "The room map is not ready. Scan more fixed features and try again."
            }
        }
    }
}

struct ARCameraView: UIViewRepresentable {
    @ObservedObject var controller: ARSessionController

    func makeUIView(context: Context) -> ARSCNView { controller.view }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
