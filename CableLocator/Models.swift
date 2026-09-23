import Foundation
import simd

struct CableMark: Codable, Identifiable {
    var id: UUID
    var label: String
    var notes: String
    var room: String
    var createdAt: Date
    var anchorID: UUID
    var position: SIMD3<Float>
    var photoName: String
    var fromLeftReferenceMM: Int?
    var fromFloorMM: Int?
    var referenceDescription: String

    init(label: String, notes: String, room: String, anchorID: UUID,
         position: SIMD3<Float>, photoName: String,
         fromLeftReferenceMM: Int?, fromFloorMM: Int?, referenceDescription: String) {
        self.id = UUID()
        self.label = label
        self.notes = notes
        self.room = room
        self.createdAt = Date()
        self.anchorID = anchorID
        self.position = position
        self.photoName = photoName
        self.fromLeftReferenceMM = fromLeftReferenceMM
        self.fromFloorMM = fromFloorMM
        self.referenceDescription = referenceDescription
    }
}

struct SiteProject: Codable, Identifiable {
    var id: UUID
    var name: String
    var address: String
    var createdAt: Date
    var marks: [CableMark]
    var worldMapName: String?

    init(name: String, address: String) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = Date()
        self.marks = []
        self.worldMapName = nil
    }
}
