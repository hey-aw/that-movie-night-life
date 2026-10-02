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
}
