import CloudKit
import Foundation

/// Explicit public projection. Never copies room identifiers, participants, night or history.
public struct PublicMovieList: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let movieSlugs: [String]
    public init(id: UUID = UUID(), room: PersistentRoom) {
        self.id = id; name = room.name; movieSlugs = room.movieSlugs
    }
    public func record() -> CKRecord {
        let record = CKRecord(recordType: "PublicList", recordID: CKRecord.ID(recordName: id.uuidString))
        record["schemaVersion"] = 1 as NSNumber
        record["name"] = name as NSString
        record["movieSlugs"] = movieSlugs as NSArray
        return record
    }
    public static func read(_ record: CKRecord) throws -> PublicMovieList {
        guard record.recordType == "PublicList", let id = UUID(uuidString: record.recordID.recordName),
              (record["schemaVersion"] as? NSNumber)?.intValue == 1,
              let name = record["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let slugs = record["movieSlugs"] as? [String], Set(slugs).count == slugs.count,
              slugs.allSatisfy({ !$0.isEmpty }) else { throw CloudRoomRecord.ContractError.invalidRecord }
        var room = PersistentRoom(name: name); room.movieSlugs = slugs
        return PublicMovieList(id: id, room: room)
    }
}
