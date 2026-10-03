import Foundation

/// Matches the web relay content-state. Times use Unix seconds, not Codable Date's reference epoch.
public struct RoomCompanionState: Codable, Hashable, Sendable {
    public var schemaVersion: Int = 1
    public var revision: String?
    public var status: NightAvailability?
    public var availableAt: Double?
    public var lastSyncedAt: Double?
    public var pending: Bool
    public var deliveryConfirmed: Bool
    public var readyCount: Int?
    public var attendingCount: Int?
    public var pendingCount: Int?

    public init(status: NightAvailability?, availableAt: Date?, lastSyncedAt: Date?, pending: Bool, deliveryConfirmed: Bool) {
        self.status = status; self.availableAt = availableAt?.timeIntervalSince1970
        self.lastSyncedAt = lastSyncedAt?.timeIntervalSince1970
        self.pending = pending; self.deliveryConfirmed = deliveryConfirmed
    }
}
