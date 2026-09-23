import Foundation
import UIKit
import ARKit

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [SiteProject] = []
    @Published var errorMessage: String?

    private let root: URL
    private let indexURL: URL

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CableLocator", isDirectory: true)
        indexURL = root.appendingPathComponent("projects.json")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                projects = try JSONDecoder().decode([SiteProject].self, from: Data(contentsOf: indexURL))
            }
        } catch {
            errorMessage = "Saved projects could not be loaded: \(error.localizedDescription)"
        }
    }

    func project(_ id: UUID) -> SiteProject? { projects.first { $0.id == id } }

    func addProject(name: String, address: String) -> UUID {
        let project = SiteProject(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  address: address.trimmingCharacters(in: .whitespacesAndNewlines))
        projects.insert(project, at: 0)
        persist()
        return project.id
    }

    func addMark(_ mark: CableMark, photo: UIImage, worldMap: ARWorldMap, to projectID: UUID) throws {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        guard let photoData = photo.jpegData(compressionQuality: 0.85) else {
            throw StoreError.photoEncoding
        }
        let photoURL = root.appendingPathComponent(mark.photoName)
        let mapName = "\(projectID.uuidString).worldmap"
        let mapURL = root.appendingPathComponent(mapName)
        let mapData = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try photoData.write(to: photoURL, options: .atomic)
        try mapData.write(to: mapURL, options: .atomic)
        projects[index].worldMapName = mapName
        projects[index].marks.append(mark)
        persist()
    }

    func image(for mark: CableMark) -> UIImage? {
        UIImage(contentsOfFile: root.appendingPathComponent(mark.photoName).path)
    }

    func worldMap(for project: SiteProject) -> ARWorldMap? {
        guard let name = project.worldMapName,
              let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    func deleteMark(_ markID: UUID, from projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }),
              let markIndex = projects[index].marks.firstIndex(where: { $0.id == markID }) else { return }
        let mark = projects[index].marks.remove(at: markIndex)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(mark.photoName))
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            errorMessage = "Changes could not be saved: \(error.localizedDescription)"
        }
    }

    enum StoreError: LocalizedError {
        case photoEncoding
        var errorDescription: String? { "The site photo could not be saved." }
    }
}
