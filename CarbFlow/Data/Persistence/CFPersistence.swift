import CoreData
import Foundation

@MainActor
final class CFPersistence {
    static let shared = CFPersistence()

    fileprivate let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "CarbFlow")
        configurePersistentStoreDescriptions()
        loadPersistentStores()
        configure(context: container.viewContext, name: "viewContext")
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        configure(context: context, name: "backgroundContext")
        return context
    }

    private func configurePersistentStoreDescriptions() {
        let description: NSPersistentStoreDescription

        if let first = container.persistentStoreDescriptions.first {
            description = first
        } else {
            description = NSPersistentStoreDescription()
            container.persistentStoreDescriptions = [description]
        }

        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
    }

    fileprivate func loadPersistentStores() {
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                assertionFailure("Unresolved Core Data error: \(error), \(error.userInfo)")
            } else {
                #if DEBUG
                if let url = description.url {
                    print("[CFPersistence] Store loaded at \(url.path)")
                }
                #endif
            }
        }
    }

    fileprivate func configure(context: NSManagedObjectContext, name: String) {
        context.name = name
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.shouldDeleteInaccessibleFaults = true
        context.undoManager = nil
    }
}

#if DEBUG
@MainActor
func cf_resetStore() {
    let persistence = CFPersistence.shared
    let coordinator = persistence.container.persistentStoreCoordinator

    for store in coordinator.persistentStores {
        do {
            try coordinator.remove(store)
        } catch {
            assertionFailure("Failed to remove persistent store: \(error)")
            continue
        }

        guard let url = store.url else {
            continue
        }

        do {
            let options: [AnyHashable: Any]? = nil
            try coordinator.destroyPersistentStore(at: url, ofType: store.type, options: options)
            try removeSQLiteSidecars(for: url)
        } catch {
            assertionFailure("Failed to destroy persistent store at \(url): \(error)")
        }
    }

    persistence.reloadPersistentStoresForDebug()
}

private func removeSQLiteSidecars(for sqliteURL: URL) throws {
    let fileManager = FileManager.default
    let basePath = sqliteURL.path

    for suffix in ["-wal", "-shm"] {
        let sidecar = URL(fileURLWithPath: basePath + suffix)
        if fileManager.fileExists(atPath: sidecar.path) {
            try fileManager.removeItem(at: sidecar)
        }
    }
}

private extension CFPersistence {
    func reloadPersistentStoresForDebug() {
        loadPersistentStores()
        configure(context: container.viewContext, name: "viewContext")
    }
}
#endif
