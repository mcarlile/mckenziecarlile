import Foundation

struct Dive: Identifiable, Codable {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var maxDepth: Double            // meters
    var avgDepth: Double            // meters
    var waterTemperature: Double?   // celsius
    var location: DiveLocation?
    var profile: [DepthSample]
    var buddyIDs: [UUID]
    var notes: String
    var diveSiteName: String?
    var workoutID: UUID?

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var maxDepthFormatted: String {
        String(format: "%.1fm", maxDepth)
    }

    var temperatureFormatted: String? {
        guard let t = waterTemperature else { return nil }
        return String(format: "%.1f°C", t)
    }
}

struct DepthSample: Identifiable, Codable {
    var id: UUID
    var timestamp: Date
    var depth: Double               // meters, positive = deeper
    var waterTemperature: Double?   // celsius

    var elapsedSeconds: Double = 0  // set relative to dive start after fetch
}

struct DiveLocation: Codable {
    var latitude: Double
    var longitude: Double
    var name: String?
}
