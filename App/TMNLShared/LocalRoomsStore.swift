import Foundation
import Observation

@MainActor
@Observable
final class LocalRoomsStore {
    private(set) var rooms: [PersistentRoom] = []
    private(set) var errorMessage: String?
    private var repository: LocalRoomRepository?

    init() {
        do {
            let repository = try LocalRoomRepository()
            rooms = try repository.load()
            self.repository = repository
        } catch { errorMessage = error.localizedDescription }
    }

    func save(_ room: PersistentRoom) {
        guard let repository else { return }
        do {
            try repository.save(room)
            if let index = rooms.firstIndex(where: { $0.id == room.id }) { rooms[index] = room }
            else { rooms.append(room) }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    var canSave: Bool { repository != nil }
}
