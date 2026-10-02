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
        return Header(id: id, name: name, selectionMode: mode, movieSlugs: slugs, currentMovieSlug: current)
    }
}
