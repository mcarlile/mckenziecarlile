import Foundation
import Combine

@MainActor
class DiveStore: ObservableObject {
    @Published var dives: [Dive] = []
    @Published var buddies: [Buddy] = []

    private let divesKey = "savedDives"
    private let buddiesKey = "savedBuddies"

    init() {
        load()
    }

    // MARK: - Dives

    func upsert(_ dive: Dive) {
        if let idx = dives.firstIndex(where: { $0.id == dive.id }) {
            dives[idx] = dive
        } else {
            dives.insert(dive, at: 0)
        }
        save()
    }

    func upsert(_ incoming: [Dive]) {
        for dive in incoming { upsert(dive) }
    }

    func delete(_ dive: Dive) {
        dives.removeAll { $0.id == dive.id }
        save()
    }

    // MARK: - Buddies

    func upsert(_ buddy: Buddy) {
        if let idx = buddies.firstIndex(where: { $0.id == buddy.id }) {
            buddies[idx] = buddy
        } else {
            buddies.append(buddy)
        }
        save()
    }

    func delete(_ buddy: Buddy) {
        buddies.removeAll { $0.id == buddy.id }
        // Untag buddy from all dives
        for i in dives.indices {
            dives[i].buddyIDs.removeAll { $0 == buddy.id }
        }
        save()
    }

    func tagBuddy(_ buddyID: UUID, on diveID: UUID) {
        guard let diveIdx = dives.firstIndex(where: { $0.id == diveID }),
              let buddyIdx = buddies.firstIndex(where: { $0.id == buddyID }) else { return }
        if !dives[diveIdx].buddyIDs.contains(buddyID) {
            dives[diveIdx].buddyIDs.append(buddyID)
        }
        if !buddies[buddyIdx].taggedDiveIDs.contains(diveID) {
            buddies[buddyIdx].taggedDiveIDs.append(diveID)
        }
        save()
    }

    func untagBuddy(_ buddyID: UUID, from diveID: UUID) {
        guard let diveIdx = dives.firstIndex(where: { $0.id == diveID }),
              let buddyIdx = buddies.firstIndex(where: { $0.id == buddyID }) else { return }
        dives[diveIdx].buddyIDs.removeAll { $0 == buddyID }
        buddies[buddyIdx].taggedDiveIDs.removeAll { $0 == diveID }
        save()
    }

    func buddies(for dive: Dive) -> [Buddy] {
        buddies.filter { dive.buddyIDs.contains($0.id) }
    }

    func dives(for buddy: Buddy) -> [Dive] {
        dives.filter { buddy.taggedDiveIDs.contains($0.id) }
    }

    // MARK: - Sharing

    func sharePackage(for dive: Dive) -> SharedDivePackage {
        SharedDivePackage(
            dive: dive,
            senderName: "Me",
            senderID: UUID(),
            sharedAt: Date()
        )
    }

    func importSharedPackage(_ package: SharedDivePackage) {
        var imported = package.dive
        imported.id = UUID() // fresh ID on import
        imported.notes = "Shared by \(package.senderName)"
        upsert(imported)
    }

    // MARK: - Persistence

    private func save() {
        if let d = try? JSONEncoder().encode(dives) { UserDefaults.standard.set(d, forKey: divesKey) }
        if let b = try? JSONEncoder().encode(buddies) { UserDefaults.standard.set(b, forKey: buddiesKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: divesKey),
           let decoded = try? JSONDecoder().decode([Dive].self, from: d) {
            dives = decoded
        }
        if let b = UserDefaults.standard.data(forKey: buddiesKey),
           let decoded = try? JSONDecoder().decode([Buddy].self, from: b) {
            buddies = decoded
        }
    }
}
