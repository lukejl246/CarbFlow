import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CarbFlow")

        let description: NSPersistentStoreDescription
        if let first = container.persistentStoreDescriptions.first {
            description = first
        } else {
            description = NSPersistentStoreDescription()
            container.persistentStoreDescriptions = [description]
        }

        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error: \(error), \(error.userInfo)")
            }
            #if DEBUG
            let location = storeDescription.url?.absoluteString ?? "in-memory"
            print("[Persistence] Store URL: \(location)")
            #endif
        }

        configureContext(container.viewContext, name: "viewContext")
    }

    private func configureContext(_ context: NSManagedObjectContext, name: String) {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.name = name
        context.undoManager = nil
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        configureContext(context, name: "backgroundContext")
        return context
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            self.configureContext(context, name: "backgroundTaskContext")
            block(context)
        }
    }
}
