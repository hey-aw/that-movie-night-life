import CloudKit
import XCTest
@testable import TMNLCore

final class CloudRoomRecordTests: XCTestCase {
    func testExplicitRecordFieldsRoundTripAndSelectionRemoval() throws {
        var room = PersistentRoom(name: "Friday")
        room.addMovie("a")
        room.selectionMode = .listOrder
        room.pick()
        let zone = CKRecordZone.ID(zoneName: "room-zone", ownerName: CKCurrentUserDefaultName)
        let record = try CloudRoomRecord.make(room, zoneID: zone)
        let header = try CloudRoomRecord.read(record)
        XCTAssertEqual(record.recordID.zoneID, zone)
        XCTAssertEqual(header.id, room.id)
        XCTAssertEqual(header.currentMovieSlug, "a")
        XCTAssertEqual(header.movieSlugs, ["a"])
        room.clearSelection()
        try CloudRoomRecord.apply(room, to: record)
        XCTAssertNil(try CloudRoomRecord.read(record).currentMovieSlug)
    }

    func testRejectsUnsupportedSchemaAndWrongRecordIdentity() throws {
        let room = PersistentRoom(name: "Friday")
        let zone = CKRecordZone.ID(zoneName: "room-zone", ownerName: CKCurrentUserDefaultName)
        let record = try CloudRoomRecord.make(room, zoneID: zone)
        record["schemaVersion"] = 2 as NSNumber
        XCTAssertThrowsError(try CloudRoomRecord.read(record))
        XCTAssertThrowsError(try CloudRoomRecord.apply(PersistentRoom(name: "Other"), to: record))
    }
    func testHistoryAndNightRoundTrip() throws {
        var room = PersistentRoom(name: "Friday")
        room.addMovie("a")
        room.pick()
        room.markWatched(now: Date(timeIntervalSince1970: 100))
        room.night = RoomNight(now: Date(timeIntervalSince1970: 200))
        let zone = CKRecordZone.ID(zoneName: "room-zone", ownerName: CKCurrentUserDefaultName)
        let record = try CloudRoomRecord.make(room, zoneID: zone)
        let header = try CloudRoomRecord.read(record)
        XCTAssertEqual(header.history, room.history)
        XCTAssertEqual(header.nightID, room.night?.id)
        XCTAssertEqual(header.room.history, room.history)
    }

    @MainActor
    func testAvailabilityRecordNeverInfersReadyFromPastETA() throws {
        let nightID = UUID()
        let record = CKRecord(recordType: "NightAvailability")
        record["nightID"] = nightID.uuidString as NSString
        record["status"] = "delayed" as NSString
        record["updatedAt"] = Date(timeIntervalSince1970: 100) as NSDate
        record["availableAt"] = Date(timeIntervalSince1970: 200) as NSDate
        let night = try CloudRoomClient.readAvailability(record, nightID: nightID)
        XCTAssertEqual(night.status, .delayed)
        XCTAssertEqual(night.availableAt, Date(timeIntervalSince1970: 200))
        XCTAssertThrowsError(try CloudRoomClient.readAvailability(record, nightID: UUID()))
    }
    func testRelayCompanionJSONUsesUnixTimestamps() throws {
        let json = """
        {"schemaVersion":1,"revision":"r1","readyCount":2,"attendingCount":3,"pendingCount":1,"lastSyncedAt":1700000000,"pending":false,"deliveryConfirmed":false}
        """
        let state = try JSONDecoder().decode(RoomCompanionState.self, from: Data(json.utf8))
        XCTAssertEqual(state.readyCount, 2)
        XCTAssertEqual(state.lastSyncedAt, 1700000000)
        XCTAssertNil(state.status)
        XCTAssertFalse(state.deliveryConfirmed)
    }
}
