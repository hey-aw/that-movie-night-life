import Foundation

/// SharePlay lobby hints are ephemeral; they never authorize CloudKit writes.
public struct RoomLobbyMessage: Codable, Equatable, Sendable {
    public let roomID: UUID
    public let nightID: UUID
    public let sequence: Int
    public let sentAt: Date
    public let movieSlug: String?
    public let availability: NightAvailability
    public let availableAt: Date?
    public init?(room: PersistentRoom, sequence: Int, now: Date = Date()) {
        guard let night = room.night else { return nil }
        roomID = room.id; nightID = night.id; self.sequence = sequence; sentAt = now
        movieSlug = room.currentMovieSlug; availability = night.status; availableAt = night.availableAt
    }
    public func isValid(for room: PersistentRoom, after previousSequence: Int?, now: Date = Date()) -> Bool {
        room.id == roomID && room.night?.id == nightID && sequence >= 0 &&
        (previousSequence == nil || sequence > previousSequence!) &&
        sentAt <= now.addingTimeInterval(30) && sentAt >= now.addingTimeInterval(-120) &&
        (movieSlug == nil || room.movieSlugs.contains(movieSlug!)) &&
        (availability == .delayed ? availableAt != nil : availableAt == nil)
    }
}
