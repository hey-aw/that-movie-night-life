import ActivityKit
import Foundation

struct RoomActivityAttributes: ActivityAttributes, Sendable {
    typealias ContentState = RoomCompanionState
    var roomName: String
    var nightID: UUID
    var roomID: UUID
    var zoneName: String
    var ownerName: String
    var isShared: Bool
    var containerIdentifier: String

    var location: CloudRoomLocation {
        CloudRoomLocation(roomID: roomID, zoneName: zoneName, ownerName: ownerName, isShared: isShared)
    }
}
