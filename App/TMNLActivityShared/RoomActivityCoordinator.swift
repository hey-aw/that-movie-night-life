import ActivityKit
import Foundation

@MainActor
enum RoomActivityCoordinator {
    static func start(room: PersistentRoom, lastSyncedAt: Date?) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let location = room.cloudLocation, let night = room.night,
              let identifier = Bundle.main.object(forInfoDictionaryKey: "TMNLCloudKitContainerIdentifier") as? String,
              !identifier.isEmpty else { return }
        let attributes = RoomActivityAttributes(roomName: room.name, nightID: night.id, roomID: room.id,
                                                 zoneName: location.zoneName, ownerName: location.ownerName,
                                                 isShared: location.isShared, containerIdentifier: identifier)
        let state = RoomActivityAttributes.ContentState(status: night.status, availableAt: night.availableAt,
                                                        lastSyncedAt: lastSyncedAt, pending: false, deliveryConfirmed: false)
        _ = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: lastSyncedAt?.addingTimeInterval(120) ?? .distantPast), pushType: .token)
        // Token registration with the relay is deliberately gated on verified authenticated protocol.
    }
}
