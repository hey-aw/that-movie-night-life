import CloudKit
import CryptoKit
import Foundation

public struct CloudRoomLocation: Codable, Equatable, Sendable {
    public let roomID: UUID
    public let zoneName: String
    public let ownerName: String
    public let isShared: Bool
    public init(roomID: UUID, zoneName: String, ownerName: String, isShared: Bool) {
        self.roomID = roomID; self.zoneName = zoneName; self.ownerName = ownerName; self.isShared = isShared
    }
    public var recordID: CKRecord.ID {
        CKRecord.ID(recordName: roomID.uuidString, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName))
    }
}

public struct CloudRoomSnapshot: Sendable {
    public let room: PersistentRoom
    public let location: CloudRoomLocation
}

/// Explicit CloudKit records are the authority. Core Data stores only cached snapshots.
/// Configuration is injected; constructing this client never chooses or registers a container.
@MainActor
public final class CloudRoomClient {
    private let container: CKContainer
    public init(container: CKContainer) { self.container = container }

    public enum ClientError: Error { case accountUnavailable, nightChanged, invalidResponse, conflict }
    private func database(_ location: CloudRoomLocation) -> CKDatabase {
        location.isShared ? container.sharedCloudDatabase : container.privateCloudDatabase
    }
    public func requireAccount() async throws {
        guard try await container.accountStatus() == .available else { throw ClientError.accountUnavailable }
    }

    public func create(_ room: PersistentRoom) async throws -> CloudRoomSnapshot {
        try await requireAccount()
        let zone = CKRecordZone(zoneName: "room-\(room.id.uuidString)")
        _ = try await container.privateCloudDatabase.save(zone)
        let record = try CloudRoomRecord.make(room, zoneID: zone.zoneID)
        _ = try await container.privateCloudDatabase.save(record)
        return CloudRoomSnapshot(room: room, location: CloudRoomLocation(roomID: room.id, zoneName: zone.zoneID.zoneName, ownerName: zone.zoneID.ownerName, isShared: false))
    }

    public func load(_ location: CloudRoomLocation) async throws -> PersistentRoom {
        let record = try await database(location).record(for: location.recordID)
        var room = try CloudRoomRecord.read(record).room
        if let night = room.night {
            let actor = try await container.userRecordID().recordName
            let id = availabilityID(location: location, nightID: night.id, actor: actor)
            do {
                let response = try await database(location).record(for: id)
                room.night = try Self.readAvailability(response, nightID: night.id)
            } catch let error as CKError where error.code == .unknownItem { /* No response yet. */ }
        }
        return room
    }

    /// All root writes use a server change tag. Conflict errors are surfaced, never silently overwritten.
    public func save(_ room: PersistentRoom, replacing expected: PersistentRoom, at location: CloudRoomLocation) async throws {
        let db = database(location)
        let record = try await db.record(for: location.recordID)
        // Do not overwrite a concurrently changed root with a stale local cache.
        let authoritative = try CloudRoomRecord.read(record).room
        let expectedHeader = try CloudRoomRecord.read(CloudRoomRecord.make(expected, zoneID: location.recordID.zoneID))
        guard try CloudRoomRecord.read(record) == expectedHeader else { throw ClientError.conflict }
        guard authoritative.id == room.id else { throw ClientError.invalidResponse }
        try CloudRoomRecord.apply(room, to: record)
        let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        guard let saved = result.saveResults[record.recordID] else { throw ClientError.invalidResponse }
        _ = try saved.get()
    }

    public func list() async throws -> [CloudRoomSnapshot] {
        try await requireAccount()
        var snapshots: [CloudRoomSnapshot] = []
        for (db, shared) in [(container.privateCloudDatabase, false), (container.sharedCloudDatabase, true)] {
            let zones = try await db.allRecordZones()
            for zone in zones {
                let query = CKQuery(recordType: CloudRoomRecord.recordType, predicate: NSPredicate(value: true))
                var page = try await db.records(matching: query, inZoneWith: zone.zoneID)
                while true {
                    for (_, result) in page.matchResults {
                        let record = try result.get()
                        let header = try CloudRoomRecord.read(record)
                        let location = CloudRoomLocation(roomID: header.id, zoneName: zone.zoneID.zoneName, ownerName: zone.zoneID.ownerName, isShared: shared)
                        let room = try await load(location)
                        snapshots.append(CloudRoomSnapshot(room: room, location: location))
                    }
                    guard let cursor = page.queryCursor else { break }
                    page = try await db.records(continuingMatchFrom: cursor)
                }
            }
        }
        return snapshots
    }

    /// Use the returned CKShare with Apple's sharing UI. No invitation is sent by this method.
    public func prepareShare(_ location: CloudRoomLocation) async throws -> CKShare {
        guard !location.isShared else { throw ClientError.invalidResponse }
        let db = database(location)
        let root = try await db.record(for: location.recordID)
        if let reference = root.share {
            guard let share = try await db.record(for: reference.recordID) as? CKShare else { throw ClientError.invalidResponse }
            return share
        }
        let share = CKShare(rootRecord: root)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = root["name"]
        let result = try await db.modifyRecords(saving: [root, share], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        _ = try result.saveResults[root.recordID]?.get()
        guard let saved = try result.saveResults[share.recordID]?.get() as? CKShare else { throw ClientError.invalidResponse }
        return saved
    }

    // Schema must grant authenticated create, creator write, and world read;
    // clients cannot enforce public database roles. Enable only after verification.
    public func publishPublicList(_ list: PublicMovieList) async throws {
        try await requireAccount()
        _ = try await container.publicCloudDatabase.save(list.record())
    }

    public func publicLists() async throws -> [PublicMovieList] {
        var lists: [PublicMovieList] = []
        var page = try await container.publicCloudDatabase.records(matching: CKQuery(recordType: "PublicList", predicate: NSPredicate(value: true)))
        while true {
            for (_, result) in page.matchResults { lists.append(try PublicMovieList.read(result.get())) }
            guard let cursor = page.queryCursor else { break }
            page = try await container.publicCloudDatabase.records(continuingMatchFrom: cursor)
        }
        return lists
    }

    public func unpublishPublicList(_ id: UUID) async throws {
        _ = try await container.publicCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: id.uuidString))
    }

    public func accept(_ metadata: CKShare.Metadata) async throws { _ = try await container.accept(metadata) }

    /// One response record per iCloud participant/night. ETA expiry never mutates status.
    public func respond(at location: CloudRoomLocation, nightID: UUID, status: NightAvailability, delay: TimeInterval? = nil) async throws -> RoomNight {
        let db = database(location)
        let root = try await db.record(for: location.recordID)
        guard try CloudRoomRecord.read(root).nightID == nightID else { throw ClientError.nightChanged }
        let actor = try await container.userRecordID().recordName
        let id = availabilityID(location: location, nightID: nightID, actor: actor)
        let record: CKRecord
        do { record = try await db.record(for: id) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: "NightAvailability", recordID: id) }
        var response = RoomNight(id: nightID)
        response.respond(status, delay: delay)
        record.parent = CKRecord.Reference(recordID: root.recordID, action: .none)
        record["room"] = CKRecord.Reference(recordID: root.recordID, action: .deleteSelf)
        record["nightID"] = nightID.uuidString as NSString
        record["participantRecordName"] = actor as NSString
        record["status"] = status.rawValue as NSString
        record["updatedAt"] = response.updatedAt as NSDate
        record["availableAt"] = response.availableAt.map { $0 as NSDate }
        let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        guard let saved = result.saveResults[id] else { throw ClientError.invalidResponse }
        _ = try saved.get()
        return response
    }

    private func availabilityID(location: CloudRoomLocation, nightID: UUID, actor: String) -> CKRecord.ID {
        let hash = SHA256.hash(data: Data(actor.utf8)).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: "availability-\(nightID.uuidString)-\(hash)", zoneID: location.recordID.zoneID)
    }
    public static func readAvailability(_ record: CKRecord, nightID: UUID) throws -> RoomNight {
        guard record.recordType == "NightAvailability", record["nightID"] as? String == nightID.uuidString,
              let value = record["status"] as? String, let status = NightAvailability(rawValue: value),
              let updated = record["updatedAt"] as? Date else { throw ClientError.invalidResponse }
        var night = RoomNight(id: nightID, now: updated)
        let eta = record["availableAt"] as? Date
        night.respond(status, now: updated, delay: eta.map { $0.timeIntervalSince(updated) })
        return night
    }
}
