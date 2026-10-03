import Combine
import GroupActivities
import Observation
import SwiftUI

struct RoomLobbyActivity: GroupActivity, Sendable {
    static let activityIdentifier = "com.aw.ThatMovieNightLife.room-lobby"
    let roomID: UUID
    let nightID: UUID
    var metadata: GroupActivityMetadata {
        var value = GroupActivityMetadata()
        value.title = "Movie night lobby"
        value.subtitle = "Coordinate the pick and readiness in That Movie Night Life"
        value.type = .generic
        return value
    }
}

@MainActor @Observable
final class RoomSharePlay {
    private(set) var connected = false
    private(set) var hints: [UUID: RoomLobbyMessage] = [:]
    private(set) var error: String?
    @ObservationIgnored private var session: GroupSession<RoomLobbyActivity>?
    @ObservationIgnored private var messenger: GroupSessionMessenger?
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var sequence = 0

    func listen(room: @escaping @MainActor () -> PersistentRoom?) async {
        for await session in RoomLobbyActivity.sessions() {
            guard !Task.isCancelled else { return }
            guard let current = room(), current.cloudLocation != nil,
                  current.id == session.activity.roomID, current.night?.id == session.activity.nightID else { continue }
            leave()
            self.session = session
            let messenger = GroupSessionMessenger(session: session)
            self.messenger = messenger
            session.$state.sink { [weak self] state in
                Task { @MainActor in
                    if case .invalidated = state { self?.leave() }
                }
            }.store(in: &subscriptions)
            session.$activeParticipants.sink { [weak self] participants in
                let ids = Set(participants.map(\.id))
                Task { @MainActor in self?.hints = self?.hints.filter { ids.contains($0.key) } ?? [:] }
            }.store(in: &subscriptions)
            receiveTask = Task { [weak self] in
                for await (message, context) in messenger.messages(of: RoomLobbyMessage.self) {
                    guard let self, self.session === session, let current = room(),
                          session.activeParticipants.contains(context.source),
                          message.isValid(for: current, after: self.hints[context.source.id]?.sequence) else { continue }
                    self.hints[context.source.id] = message
                }
            }
            session.join()
            connected = true
            await send(room: current)
        }
    }

    func start(room: PersistentRoom) async {
        guard room.cloudLocation != nil, let night = room.night else { return }
        do {
            let activity = RoomLobbyActivity(roomID: room.id, nightID: night.id)
            if await activity.prepareForActivation() == .activationPreferred { _ = try await activity.activate() }
        } catch { self.error = error.localizedDescription }
    }

    func send(room: PersistentRoom) async {
        guard let session, let messenger, let night = room.night,
              room.id == session.activity.roomID, night.id == session.activity.nightID else { leave(); return }
        sequence += 1
        guard let message = RoomLobbyMessage(room: room, sequence: sequence) else { return }
        do { try await messenger.send(message) }
        catch { self.error = error.localizedDescription }
    }

    func leave() {
        receiveTask?.cancel(); receiveTask = nil
        subscriptions.removeAll(); session?.leave(); session = nil; messenger = nil
        hints = [:]; connected = false; sequence = 0
    }
}
