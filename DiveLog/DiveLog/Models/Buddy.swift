import Foundation

struct Buddy: Identifiable, Codable {
    var id: UUID
    var name: String
    var email: String?
    var cloudKitRecordName: String?
    var avatarData: Data?

    // Dives this buddy has been tagged in (local dive IDs)
    var taggedDiveIDs: [UUID]

    // Dives shared to this buddy for import
    var sharedDiveIDs: [UUID]

    init(id: UUID = UUID(), name: String, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.taggedDiveIDs = []
        self.sharedDiveIDs = []
    }

    var initials: String {
        name.split(separator: " ")
            .compactMap { $0.first.map { String($0) } }
            .prefix(2)
            .joined()
            .uppercased()
    }
}

struct SharedDivePackage: Codable {
    var dive: Dive
    var senderName: String
    var senderID: UUID
    var sharedAt: Date
}
