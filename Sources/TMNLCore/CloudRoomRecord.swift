import CloudKit
import Foundation

/// Explicit native/web record contract. This is not a mirrored Core Data schema.
/// Membership, sharing and mutation authorization must be verified before remote use.
public enum CloudRoomRecord {
    public static let recordType = "Room"
    public static let schemaVersion = 1

    public struct Header: Equatable, Sendable {
        public let id: UUID
        public let name: String
        public let selectionMode: RoomSelectionMode
        public let movieSlugs: [String]
        public let currentMovieSlug: String?
        public let history: [RoomWatch]
        public let nightID: UUID?
        public let faceTimeLink: String?

        public var room: PersistentRoom {
            PersistentRoom(id: id, name: name, movieSlugs: movieSlugs, selectionMode: selectionMode,
                           currentMovieSlug: currentMovieSlug, history: history,
                           night: nightID.map { RoomNight(id: $0) }, faceTimeLink: faceTimeLink)
        }
    }

    public enum ContractError: Error {
        case invalidRecord, unsupportedVersion, wrongIdentity
    }

    /// Updating the fetched record preserves CloudKit system fields/change tag.
    /// Callers must save with ifServerRecordUnchanged and reconcile conflicts.
    public static func apply(_ room: PersistentRoom, to record: CKRecord) throws {
        guard record.recordType == recordType,
              record.recordID.recordName == room.id.uuidString else { throw ContractError.wrongIdentity }
        record["schemaVersion"] = schemaVersion as NSNumber
        record["name"] = room.name as NSString
        record["selectionMode"] = room.selectionMode.rawValue as NSString
        record["movieSlugs"] = room.movieSlugs as NSArray
        record["currentMovieSlug"] = room.currentMovieSlug.map { $0 as NSString }
        record["watchIDs"] = room.history.map { $0.id.uuidString } as NSArray
        record["watchSlugs"] = room.history.map(\.movieSlug) as NSArray
        record["watchDates"] = room.history.map(\.watchedAt) as NSArray
        record["nightID"] = room.night.map { $0.id.uuidString as NSString }
        guard room.faceTimeLink == nil || RoomLinks.faceTime(room.faceTimeLink!) != nil else { throw ContractError.invalidRecord }
        record["faceTimeLink"] = room.faceTimeLink.map { $0 as NSString }
    }

    public static func make(_ room: PersistentRoom, zoneID: CKRecordZone.ID) throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: room.id.uuidString, zoneID: zoneID))
        try apply(room, to: record)
        return record
    }

    public static func read(_ record: CKRecord) throws -> Header {
        guard record.recordType == recordType,
              let id = UUID(uuidString: record.recordID.recordName),
              let version = record["schemaVersion"] as? NSNumber else { throw ContractError.invalidRecord }
        guard version.intValue == schemaVersion else { throw ContractError.unsupportedVersion }
        guard let name = record["name"] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let modeString = record["selectionMode"] as? String,
              let mode = RoomSelectionMode(rawValue: modeString),
              let slugs = record["movieSlugs"] as? [String],
              Set(slugs).count == slugs.count,
              slugs.allSatisfy({ !$0.isEmpty }) else { throw ContractError.invalidRecord }
        let current = record["currentMovieSlug"] as? String
        if let current, !slugs.contains(current) { throw ContractError.invalidRecord }
        let watchIDs = record["watchIDs"] as? [String] ?? []
        let watchSlugs = record["watchSlugs"] as? [String] ?? []
        let watchDates = record["watchDates"] as? [Date] ?? []
        guard watchIDs.count == watchSlugs.count, watchIDs.count == watchDates.count else { throw ContractError.invalidRecord }
        let history = try watchIDs.enumerated().map { index, value in
            guard let id = UUID(uuidString: value) else { throw ContractError.invalidRecord }
            return RoomWatch(id: id, movieSlug: watchSlugs[index], watchedAt: watchDates[index])
        }
        let nightString = record["nightID"] as? String
        let nightID = nightString.flatMap(UUID.init(uuidString:))
        guard nightString == nil || nightID != nil else { throw ContractError.invalidRecord }
        let faceTimeLink = record["faceTimeLink"] as? String
        guard faceTimeLink == nil || RoomLinks.faceTime(faceTimeLink!) != nil else { throw ContractError.invalidRecord }
        return Header(id: id, name: name, selectionMode: mode, movieSlugs: slugs, currentMovieSlug: current, history: history, nightID: nightID, faceTimeLink: faceTimeLink)
    }
}
