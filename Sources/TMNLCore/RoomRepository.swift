import Foundation

public struct PersistedRoomState: Codable, Equatable, Sendable {
    public var activeRoomID: UUID?
    public var rooms: [Room]

    public init(activeRoomID: UUID? = nil, rooms: [Room] = []) {
        self.activeRoomID = activeRoomID
        self.rooms = rooms
    }
}

public protocol RoomRepositoryProtocol {
    func loadState() throws -> PersistedRoomState?
    func saveState(_ state: PersistedRoomState) throws
    func seededRooms(using catalog: [Movie]) -> [Room]
}

public final class UserDefaultsRoomRepository: RoomRepositoryProtocol {
    private static let key = "tmnl.rooms"
    private let defaults: UserDefaults
    private let seedLoader: RoomSeedLoading

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, seedLoader: LocalRoomSeedLoader())
    }

    init(defaults: UserDefaults = .standard, seedLoader: RoomSeedLoading) {
        self.defaults = defaults
        self.seedLoader = seedLoader
    }

    public func loadState() throws -> PersistedRoomState? {
        guard let data = defaults.data(forKey: Self.key) else {
            return nil
        }
        return try JSONDecoder().decode(PersistedRoomState.self, from: data)
    }

    public func saveState(_ state: PersistedRoomState) throws {
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: Self.key)
    }

    public func seededRooms(using catalog: [Movie]) -> [Room] {
        let catalogTitleIDs = Set(catalog.map(\.titleID))
        let sourceTitleIDs = seedLoader
            .seededTitleIDs(for: catalog)
            .filter { catalogTitleIDs.contains($0) }

        guard !sourceTitleIDs.isEmpty else {
            return []
        }

        return [
            Room(
                templateID: "movie-night-roulette",
                name: "Movie Night Roulette",
                source: .letterboxdList(RoomSourceList(
                    displayName: "Movie Night Roulette List",
                    orderedTitleIDs: sourceTitleIDs
                )),
                selectionMode: .random,
                members: [RoomMember(id: "owner", displayName: "You", role: .owner)]
            )
        ]
    }
}

public enum RoomSelectionEngine {
    public static func candidateTitleIDs(
        for room: Room,
        catalogByTitleID: [String: Movie],
        excludeTitleIDs: Set<String>,
        eligibleByFilters: (Movie) -> Bool
    ) -> [String] {
        let pickedTitleID = room.currentPick?.titleID
        let resolvedTitleIDs = Set(room.history.map(\.titleID))

        return room.source.list.orderedTitleIDs.compactMap { titleID in
            guard let movie = catalogByTitleID[titleID] else {
                return nil
            }
            guard pickedTitleID != titleID,
                  !resolvedTitleIDs.contains(titleID),
                  !excludeTitleIDs.contains(titleID),
                  eligibleByFilters(movie)
            else {
                return nil
            }
            return titleID
        }
    }

    public static func pick(from room: Room, candidates: [String]) -> String? {
        switch room.selectionMode {
        case .random:
            return candidates.randomElement()
        case .nextUnwatched:
            return candidates.first
        }
    }

    public static func resolvedHistoryEntry(
        from movie: Movie,
        pickedAt: Date,
        resolvedAt: Date,
        disposition: RoomHistoryDisposition
    ) -> RoomHistoryEntry {
        RoomHistoryEntry(
            titleID: movie.titleID,
            slug: movie.slug,
            number: movie.number,
            displayName: movie.displayName,
            pickedAt: pickedAt,
            resolvedAt: resolvedAt,
            disposition: disposition
        )
    }
}

protocol RoomSeedLoading: Sendable {
    func seededTitleIDs(for catalog: [Movie]) -> [String]
}

struct LocalRoomSeedLoader: RoomSeedLoading {
    func seededTitleIDs(for catalog: [Movie]) -> [String] {
        catalog.map(\.titleID)
    }
}
