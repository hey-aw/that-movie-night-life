import Foundation

public struct Room: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var members: [String]
    public var recentWatches: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        members: [String] = [],
        recentWatches: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.recentWatches = recentWatches
        self.createdAt = createdAt
    }
}
