import ARKit
import SwiftUI

private struct CapturedMark {
    let anchor: ARAnchor
    let photo: UIImage
    let map: ARWorldMap
}

struct CaptureView: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    @StateObject private var ar = ARSessionController()
    @State private var captured: CapturedMark?
    @State private var errorMessage: String?
    @State private var label = ""
    @State private var room = ""
    @State private var notes = ""
    @State private var across = ""
    @State private var height = ""
    @State private var reference = ""

    var body: some View {
        ZStack {
            ARCameraView(controller: ar).ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                    }
                    .background(.regularMaterial, in: Circle())
                    Spacer()
                    if ar.hasLiDAR {
                        Label("LiDAR active", systemImage: "sensor.tag.radiowaves.forward")
                            .font(.caption.weight(.semibold)).padding(10)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding()
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(.orange)
                    .shadow(color: .black, radius: 3)
                    .accessibilityLabel("Aim point for cable end")
                Spacer()
                VStack(spacing: 14) {
                    Text(ar.status).font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                    Button {
                        ar.captureMark { result in
                            switch result {
                            case let .success((anchor, photo, map)):
                                captured = CapturedMark(anchor: anchor, photo: photo, map: map)
                            case let .failure(error): errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Mark cable end", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!ar.readyToMark)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .tint(.orange)
        .onAppear { ar.start(mode: .capture, worldMap: store.project(projectID).flatMap(store.worldMap)) }
        .onDisappear { ar.stop() }
        .sheet(item: Binding(
            get: { captured.map { IdentifiedCapture(value: $0) } },
            set: { if $0 == nil { captured = nil } })) { item in
            markForm(item.value)
        }
        .alert("Capture problem", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func markForm(_ capture: CapturedMark) -> some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: capture.photo).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    TextField("Cable label, e.g. Kitchen GPO 3", text: $label)
                    TextField("Room", text: $room)
                    TextField("Notes or cable ID", text: $notes, axis: .vertical)
                } header: { Text("Cable end") }
                Section {
                    TextField("Reference and direction, e.g. right of door jamb", text: $reference)
                    TextField("Distance across (mm)", text: $across).keyboardType(.numberPad)
                    TextField("Height above floor datum (mm)", text: $height).keyboardType(.numberPad)
                } header: { Text("Physical check") }
                footer: { Text("Use fixed features that will still be identifiable after lining. Describe the floor datum in notes. Measure to the centre of the cable end.") }
            }
            .navigationTitle("Save cable mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retake") { captured = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(capture) }
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  (Int(across) ?? -1) < 0 || (Int(height) ?? -1) < 0)
                }
            }
        }
    }

    private func save(_ capture: CapturedMark) {
        let p = capture.anchor.transform.columns.3
        let mark = CableMark(label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                             notes: notes, room: room.trimmingCharacters(in: .whitespacesAndNewlines),
                             anchorID: capture.anchor.identifier,
                             position: SIMD3<Float>(p.x, p.y, p.z),
                             photoName: "\(UUID().uuidString).jpg",
                             fromLeftReferenceMM: Int(across), fromFloorMM: Int(height),
                             referenceDescription: reference)
        do {
            try store.addMark(mark, photo: capture.photo, worldMap: capture.map, to: projectID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct IdentifiedCapture: Identifiable {
        let value: CapturedMark
        var id: UUID { value.anchor.identifier }
    }
}

struct LocateView: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    let markID: UUID
    @StateObject private var ar = ARSessionController()
    @State private var showingPhoto = false
    @State private var mapMissing = false

    private var mark: CableMark? { store.project(projectID)?.marks.first { $0.id == markID } }

    var body: some View {
        ZStack {
            ARCameraView(controller: ar).ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                    }
                    .background(.regularMaterial, in: Circle())
                    Spacer()
                    Button { showingPhoto = true } label: {
                        Label("Photo", systemImage: "photo").padding(10)
                    }
                    .background(.regularMaterial, in: Capsule())
                }
                .padding()
                Spacer()
                VStack(spacing: 10) {
                    Text(mapMissing ? "Saved room map unavailable. Use the photo and measurements." : ar.status)
                        .font(.subheadline.weight(.medium))
                    if ar.relocalized, let distance = ar.targetDistance {
                        Text(String(format: "%.2f m to saved point", distance))
                            .font(.title2.weight(.semibold))
                    }
                    if let mark {
                        Text(measurementText(mark)).font(.footnote)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .tint(.orange)
        .onAppear {
            guard let project = store.project(projectID), let mark else { return }
            guard let map = store.worldMap(for: project) else { mapMissing = true; return }
            ar.start(mode: .locate, worldMap: map, targetAnchorID: mark.anchorID)
        }
        .onDisappear { ar.stop() }
        .sheet(isPresented: $showingPhoto) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let mark, let image = store.image(for: mark) {
                            Image(uiImage: image).resizable().scaledToFit()
                            Text(measurementText(mark)).font(.headline)
                            Text(mark.referenceDescription).foregroundStyle(.secondary)
                        }
                    }.padding()
                }
                .navigationTitle("Original photo")
                .toolbar { Button("Done") { showingPhoto = false } }
            }
        }
    }

    private func measurementText(_ mark: CableMark) -> String {
        let across = mark.fromLeftReferenceMM.map { "\($0) mm across" } ?? "Across distance not recorded"
        let height = mark.fromFloorMM.map { "\($0) mm above floor" } ?? "Height not recorded"
        return "\(across) · \(height)"
    }
}
