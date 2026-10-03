import XCTest
import CloudKit
@testable import TMNLCore

final class RoomCompanionFeatureTests: XCTestCase {
    func testFaceTimeLinksRejectImpersonationAndCredentials() {
        XCTAssertNotNil(RoomLinks.faceTime("https://facetime.apple.com/join#v=example"))
        for value in ["http://facetime.apple.com/join", "https://facetime.apple.com.evil.test/join", "https://user@facetime.apple.com/join", "javascript:alert(1)"] {
            XCTAssertNil(RoomLinks.faceTime(value))
        }
    }
    func testPublicProjectionDoesNotLeakRoomGraph() throws {
        var room = PersistentRoom(name: "Friends"); room.addMovie("alien")
        room.faceTimeLink = "https://facetime.apple.com/join#secret"
        room.night = RoomNight(); room.pick(); room.markWatched()
        let list = PublicMovieList(room: room)
        let record = list.record()
        XCTAssertEqual(Set(record.allKeys()), Set(["schemaVersion", "name", "movieSlugs"]))
        XCTAssertNotEqual(list.id, room.id)
        XCTAssertEqual(try PublicMovieList.read(record), list)
    }
    func testSharePlayHintsRejectStaleWrongNightAndReplays() {
        var room = PersistentRoom(name: "Friends"); room.addMovie("alien"); room.night = RoomNight()
        let now = Date(timeIntervalSince1970: 1000)
        let message = RoomLobbyMessage(room: room, sequence: 2, now: now)!
        XCTAssertTrue(message.isValid(for: room, after: 1, now: now))
        XCTAssertFalse(message.isValid(for: room, after: 2, now: now))
        XCTAssertFalse(message.isValid(for: room, after: nil, now: now.addingTimeInterval(121)))
        room.night = RoomNight()
        XCTAssertFalse(message.isValid(for: room, after: nil, now: now))
    }
    func testRegionalSearchEncodesTitleAndRejectsMalformedRegion() {
        let options = RoomLinks.watchSearch(title: "Alien & friends", region: "GB")
        XCTAssertEqual(options.count, 2)
        XCTAssertTrue(options[0].url.absoluteString.contains("/gb/search?"))
        XCTAssertTrue(RoomLinks.watchSearch(title: "Alien", region: "../").isEmpty)
    }
}
