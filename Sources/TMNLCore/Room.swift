import Foundation

public enum RoomMemberRole: String, Codable, Equatable, Sendable {
    case owner
    case member
}

public struct RoomMember: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let role: RoomMemberRole

    public init(id: String, displayName: String, role: RoomMemberRole = .member) {
        self.id = id
        self.displayName = displayName
        self.role = role
    }
}

public enum RoomSelectionMode: String, Codable, Equatable, Sendable, CaseIterable {
    case random
    case nextUnwatched
}

public enum RoomHistoryDisposition: String, Codable, Equatable, Sendable {
    case watched
    case seen
    case passed
}

public struct RoomCurrentPick: Codable, Equatable, Sendable {
    public let titleID: String
    public let slug: String
    public let number: Int
    public let displayName: String
    public let pickedAt: Date

    public init(titleID: String, slug: String, number: Int, displayName: String, pickedAt: Date) {
        self.titleID = titleID
        self.slug = slug
        self.number = number
        self.displayName = displayName
        self.pickedAt = pickedAt
    }
}

public struct RoomHistoryEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let titleID: String
    public let slug: String
    public let number: Int
    public let displayName: String
    public let pickedAt: Date
    public let resolvedAt: Date
    public let disposition: RoomHistoryDisposition

    public var id: String {
        "\(titleID)-\(resolvedAt.timeIntervalSince1970)"
    }

    public init(
        titleID: String,
        slug: String,
        number: Int,
        displayName: String,
        pickedAt: Date,
        resolvedAt: Date,
        disposition: RoomHistoryDisposition
    ) {
        self.titleID = titleID
        self.slug = slug
        self.number = number
        self.displayName = displayName
        self.pickedAt = pickedAt
        self.resolvedAt = resolvedAt
        self.disposition = disposition
    }
}

public struct RoomSourceList: Codable, Equatable, Sendable {
    public let displayName: String
    public let letterboxdURL: String?
    public let orderedTitleIDs: [String]

    public init(displayName: String, letterboxdURL: String? = nil, orderedTitleIDs: [String]) {
        self.displayName = displayName
        self.letterboxdURL = letterboxdURL
        self.orderedTitleIDs = orderedTitleIDs
    }
}

public enum RoomSource: Codable, Equatable, Sendable {
    case letterboxdList(RoomSourceList)

    public var list: RoomSourceList {
        switch self {
        case .letterboxdList(let list):
            return list
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case displayName
        case letterboxdURL
        case orderedTitleIDs
    }

    private enum Kind: String, Codable {
        case letterboxdList
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .letterboxdList:
            self = .letterboxdList(RoomSourceList(
                displayName: try container.decode(String.self, forKey: .displayName),
                letterboxdURL: try container.decodeIfPresent(String.self, forKey: .letterboxdURL),
                orderedTitleIDs: try container.decode([String].self, forKey: .orderedTitleIDs)
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .letterboxdList(let list):
            try container.encode(Kind.letterboxdList, forKey: .kind)
            try container.encode(list.displayName, forKey: .displayName)
            try container.encodeIfPresent(list.letterboxdURL, forKey: .letterboxdURL)
            try container.encode(list.orderedTitleIDs, forKey: .orderedTitleIDs)
        }
    }
}

public struct Room: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var templateID: String?
    public var name: String
    public var source: RoomSource
    public var selectionMode: RoomSelectionMode
    public var currentPick: RoomCurrentPick?
    public var history: [RoomHistoryEntry]
    public var members: [RoomMember]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        templateID: String? = nil,
        name: String,
        source: RoomSource,
        selectionMode: RoomSelectionMode = .random,
        currentPick: RoomCurrentPick? = nil,
        history: [RoomHistoryEntry] = [],
        members: [RoomMember] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.source = source
        self.selectionMode = selectionMode
        self.currentPick = currentPick
        self.history = history
        self.members = members
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(
        name: String,
        source: RoomSource = .letterboxdList(RoomSourceList(displayName: "Movie Night List", orderedTitleIDs: []))
    ) {
        self.init(name: name, source: source, selectionMode: .random)
    }

    public mutating func setSelectionMode(_ mode: RoomSelectionMode) {
        selectionMode = mode
        updatedAt = Date()
    }

    public mutating func setCurrentPick(_ pick: RoomCurrentPick?) {
        currentPick = pick
        updatedAt = Date()
    }

    public mutating func appendHistory(_ entry: RoomHistoryEntry) {
        history.insert(entry, at: 0)
        updatedAt = Date()
    }
}
