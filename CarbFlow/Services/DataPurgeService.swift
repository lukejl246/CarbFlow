import Foundation
import CoreData

@MainActor
final class DataPurgeService {
    private let persistence: PersistenceController
    private let userDefaults: UserDefaults

    init(
        persistence: PersistenceController = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.persistence = persistence
        self.userDefaults = userDefaults
    }

    func purgeAll() throws {
        let container = persistence.container
        let context = container.viewContext

        try container.managedObjectModel.entities
            .compactMap { $0.name }
            .forEach { entityName in
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                    let changes: [AnyHashable: Any] = [
                        NSDeletedObjectsKey: objectIDs
                    ]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [context]
                    )
                }
            }

        context.reset()

        userDefaults.dictionaryRepresentation()
            .keys
            .filter { $0.hasPrefix("cf_") }
            .forEach { userDefaults.removeObject(forKey: $0) }
        userDefaults.synchronize()
    }
}
