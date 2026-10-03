import XCTest
@testable import TMNLCore

final class PersistentRoomTests: XCTestCase {
    func testOrderedSelectionHistoryAndStablePick() throws {
        var room = PersistentRoom(name: "Friday")
        room.addMovie("a")
        room.addMovie("a")
        room.addMovie("b")
        room.selectionMode = .listOrder
        XCTAssertEqual(room.movieSlugs, ["a", "b"])
        XCTAssertEqual(room.pick(), "a")
        XCTAssertEqual(room.pick(), "a")
        let restored = try JSONDecoder().decode(PersistentRoom.self, from: JSONEncoder().encode(room))
        XCTAssertEqual(restored.currentMovieSlug, "a")
        room.markWatched(now: Date(timeIntervalSince1970: 1))
        room.markWatched()
        XCTAssertEqual(room.history.count, 1)
        XCTAssertEqual(room.pick(), "b")
        room.markWatched()
        XCTAssertNil(room.pick())
    }

    func testRandomOnlyUsesUnwatchedListAndRejectsInvalidChoice() {
        var room = PersistentRoom(name: "Friday")
        room.addMovie("a")
        room.addMovie("b")
        XCTAssertNil(room.pick { _ in "outside-list" })
        XCTAssertEqual(room.pick { $0.last }, "b")
        room.markWatched()
        XCTAssertEqual(room.pick { candidates in
            XCTAssertEqual(candidates, ["a"])
            return candidates.first
        }, "a")
    }

    func testDelayRequiresExplicitReadyAndNewNightResetsResponse() {
        let now = Date(timeIntervalSince1970: 10)
        var night = RoomNight(now: now)
        night.respond(.delayed, now: now, delay: 1800)
        XCTAssertEqual(night.availableAt, now.addingTimeInterval(1800))
        XCTAssertEqual(night.status, .delayed)
        night.respond(.ready, now: now.addingTimeInterval(2000))
        XCTAssertNil(night.availableAt)
        XCTAssertEqual(night.status, .ready)
        XCTAssertEqual(RoomNight().status, .undecided)
    }

    @MainActor
    func testSQLiteRoundTripAcrossRepositoryReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("rooms.sqlite")
        var room = PersistentRoom(name: "Durable")
        room.addMovie("a")
        room.addMovie("b")
        room.selectionMode = .listOrder
        room.pick()
        room.markWatched()
        room.pick()
        room.night = RoomNight()
        room.night?.respond(.delayed, delay: 3600)
        do {
            let repository = try LocalRoomRepository(storeURL: url)
            try repository.save(room)
            try repository.save(room)
        }
        let reopened = try LocalRoomRepository(storeURL: url)
        XCTAssertEqual(try reopened.load(), [room])
    }
}
