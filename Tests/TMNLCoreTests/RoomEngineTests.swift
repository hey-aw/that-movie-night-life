import XCTest
@testable import TMNLCore

final class RoomEngineTests: XCTestCase {
    func testCandidateTitleIDsFiltersBySourceHistoryAndCurrentPick() {
        let room = Room(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Test Room",
            source: .letterboxdList(RoomSourceList(
                displayName: "Test List",
                orderedTitleIDs: ["tmnl:alpha", "tmnl:beta", "tmnl:gamma", "tmnl:delta"]
            )),
            currentPick: RoomCurrentPick(
                titleID: "tmnl:beta",
                slug: "beta",
                number: 2,
                displayName: "Beta",
                pickedAt: Date()
            ),
            history: [
                RoomHistoryEntry(
                    titleID: "tmnl:gamma",
                    slug: "gamma",
                    number: 3,
                    displayName: "Gamma",
                    pickedAt: Date(),
                    resolvedAt: Date(),
                    disposition: .watched
                )
            ]
        )

        let catalog: [String: Movie] = [
            "tmnl:alpha": movie(number: 1, slug: "alpha", title: "Alpha", rating: 8.0),
            "tmnl:beta": movie(number: 2, slug: "beta", title: "Beta", rating: 9.0),
            "tmnl:gamma": movie(number: 3, slug: "gamma", title: "Gamma", rating: 7.0),
            "tmnl:delta": movie(number: 4, slug: "delta", title: "Delta", rating: 9.4)
        ]

        let candidates = RoomSelectionEngine.candidateTitleIDs(
            for: room,
            catalogByTitleID: catalog,
            excludeTitleIDs: ["tmnl:delta"],
            eligibleByFilters: { $0.aggregateRating ?? 0 >= 8.0 }
        )

        XCTAssertEqual(candidates, ["tmnl:alpha"])
    }

    func testNextUnwatchedPickReturnsFirstEligibleCandidate() {
        let room = Room(
            name: "Test Room",
            source: .letterboxdList(RoomSourceList(
                displayName: "Test List",
                orderedTitleIDs: ["tmnl:one", "tmnl:two", "tmnl:three"]
            )),
            selectionMode: .nextUnwatched
        )

        XCTAssertEqual(RoomSelectionEngine.pick(from: room, candidates: ["tmnl:one", "tmnl:two", "tmnl:three"]), "tmnl:one")
    }

    func testPersistedRoomStateRoundTripsThroughRepository() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "tmnl.room.tests.state"))
        defer { defaults.removePersistentDomain(forName: "tmnl.room.tests.state") }

        let repository = UserDefaultsRoomRepository(defaults: defaults, seedLoader: StubRoomSeedLoader())
        let room = Room(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Test Room",
            source: .letterboxdList(RoomSourceList(displayName: "Test", orderedTitleIDs: ["tmnl:alpha"])),
            history: [
                RoomHistoryEntry(
                    titleID: "tmnl:alpha",
                    slug: "alpha",
                    number: 1,
                    displayName: "Alpha",
                    pickedAt: Date(timeIntervalSince1970: 1),
                    resolvedAt: Date(timeIntervalSince1970: 2),
                    disposition: .seen
                )
            ],
            members: [RoomMember(id: "owner", displayName: "Owner", role: .owner)]
        )

        let state = PersistedRoomState(activeRoomID: room.id, rooms: [room])
        try repository.saveState(state)

        XCTAssertEqual(try repository.loadState(), state)
    }

    func testSeededRoomFiltersMissingCatalogTitles() {
        let repository = UserDefaultsRoomRepository(seedLoader: StubRoomSeedLoader(sequence: ["tmnl:beta", "tmnl:missing", "tmnl:gamma"]))
        let rooms = repository.seededRooms(using: [
            movie(number: 2, slug: "beta", title: "Beta", rating: 8.8),
            movie(number: 3, slug: "gamma", title: "Gamma", rating: 9.0)
        ])

        XCTAssertEqual(rooms.count, 1)
        XCTAssertEqual(rooms.first?.templateID, "movie-night-roulette")
        XCTAssertEqual(rooms.first?.source.list.orderedTitleIDs, ["tmnl:beta", "tmnl:gamma"])
    }

    func testSeededRoomToleratesDuplicateCatalogSlugs() {
        let repository = UserDefaultsRoomRepository(seedLoader: StubRoomSeedLoader(sequence: ["tmnl:blue-first"]))
        let rooms = repository.seededRooms(using: [
            movie(number: 1, slug: "three-colours-blue", titleID: "tmnl:blue-first", title: "Blue", rating: 8.8),
            movie(number: 2, slug: "three-colours-blue", titleID: "tmnl:blue-second", title: "Blue Duplicate", rating: 8.6)
        ])

        XCTAssertEqual(rooms.first?.source.list.orderedTitleIDs, ["tmnl:blue-first"])
    }
}

private final class StubRoomSeedLoader: RoomSeedLoading {
    private let sequence: [String]?

    init(sequence: [String]? = nil) {
        self.sequence = sequence
    }

    func seededTitleIDs(for catalog: [Movie]) -> [String] {
        sequence ?? catalog.map(\.titleID)
    }
}

private func movie(number: Int, slug: String, title: String, rating: Double) -> Movie {
    movie(number: number, slug: slug, titleID: nil, title: title, rating: rating)
}

private func movie(number: Int, slug: String, titleID: String?, title: String, rating: Double) -> Movie {
    Movie(
        number: number,
        slug: slug,
        titleID: titleID,
        title: title,
        year: 2020,
        displayName: "\(title) (2020)",
        letterboxdURL: "https://example.com/\(slug)",
        watchURL: "https://example.com/watch/\(slug)",
        posterURL: nil,
        aggregateRating: rating,
        ratingCount: 100,
        genres: ["Drama"],
        tmdbMovieID: nil,
        runtimeMinutes: 95,
        certification: nil,
        backdropURL: nil,
        buzzKillTags: []
    )
}
