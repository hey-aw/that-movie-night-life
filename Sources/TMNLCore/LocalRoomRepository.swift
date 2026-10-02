import CoreData
import Foundation

@MainActor
public final class LocalRoomRepository {
    private let container: NSPersistentContainer

    public init(storeURL: URL? = nil, inMemory: Bool = false) throws {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "LocalRoom"
        entity.managedObjectClassName = "NSManagedObject"
        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false
        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false
        entity.properties = [id, payload]
        model.entities = [entity]
        container = NSPersistentContainer(name: "TMNLLocalRooms", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        if !inMemory {
            let url = storeURL ?? NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("TMNLLocalRooms.sqlite")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            description.url = url
        }
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    public func load() throws -> [PersistentRoom] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LocalRoom")
        return try container.viewContext.fetch(request).map { object in
            guard let data = object.value(forKey: "payload") as? Data else {
                throw CocoaError(.coderReadCorrupt)
            }
            return try JSONDecoder().decode(PersistentRoom.self, from: data)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ room: PersistentRoom) throws {
        let context = container.viewContext
        do {
            let data = try JSONEncoder().encode(room)
            let request = NSFetchRequest<NSManagedObject>(entityName: "LocalRoom")
            request.predicate = NSPredicate(format: "id == %@", room.id as NSUUID)
            let object = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "LocalRoom", into: context)
            object.setValue(room.id, forKey: "id")
            object.setValue(data, forKey: "payload")
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
