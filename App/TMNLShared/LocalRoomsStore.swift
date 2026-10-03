import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class LocalRoomsStore {
    private(set) var rooms: [PersistentRoom] = []
    private(set) var errorMessage: String?
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private var repository: LocalRoomRepository?
    let cloudClient: CloudRoomClient?

    init() {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "TMNLCloudKitContainerIdentifier") as? String ?? ""
        cloudClient = identifier.isEmpty ? nil : CloudRoomClient(container: CKContainer(identifier: identifier))
        do {
            let repository = try LocalRoomRepository()
            rooms = try repository.load()
            self.repository = repository
        } catch { errorMessage = error.localizedDescription }
    }

    func save(_ room: PersistentRoom) {
        guard let location = room.cloudLocation, let client = cloudClient,
              let expected = rooms.first(where: { $0.id == room.id }) else { saveCache(room); return }
        guard !isSyncing else { return }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                if let nextNight = room.night, let previousNight = expected.night,
                   nextNight.id == previousNight.id, nextNight.status != previousNight.status || nextNight.updatedAt != previousNight.updatedAt {
                    _ = try await client.respond(at: location, nightID: nextNight.id, status: nextNight.status,
                                                 delay: nextNight.availableAt.map { $0.timeIntervalSince(nextNight.updatedAt) })
                } else {
                    try await client.save(room, replacing: expected, at: location)
                }
                var loaded = try await client.load(location)
                loaded.cloudLocation = location
                saveCache(loaded)
                lastSyncedAt = Date()
            } catch { errorMessage = "iCloud change not confirmed: \(error.localizedDescription). Refresh before retrying." }
        }
    }

    private func saveCache(_ room: PersistentRoom) {
        guard let repository else { return }
        do {
            try repository.save(room)
            if let index = rooms.firstIndex(where: { $0.id == room.id }) { rooms[index] = room }
            else { rooms.append(room) }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func publish(_ room: PersistentRoom) async {
        guard let client = cloudClient, !isSyncing, room.cloudLocation == nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let snapshot = try await client.create(room)
            var cached = snapshot.room
            cached.cloudLocation = snapshot.location
            saveCache(cached)
            lastSyncedAt = Date()
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        guard let client = cloudClient, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let snapshots = try await client.list()
            for snapshot in snapshots {
                var cached = snapshot.room
                cached.cloudLocation = snapshot.location
                saveCache(cached)
            }
            lastSyncedAt = Date()
        } catch { errorMessage = error.localizedDescription }
    }

    func reportShareError(_ message: String) { errorMessage = message }

    var canSave: Bool { repository != nil && !isSyncing }
}
