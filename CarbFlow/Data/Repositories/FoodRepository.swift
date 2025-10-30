import CoreData
import Foundation

protocol FoodRepositoryProtocol {
    func searchFoods(prefix: String, limit: Int) async throws -> [Food]
    func food(by id: UUID) async throws -> Food?
    func countAll() async throws -> Int
}

@MainActor
final class FoodRepository: FoodRepositoryProtocol {
    private let persistence: CFPersistence

    init(persistence: CFPersistence) {
        self.persistence = persistence
    }

    func searchFoods(prefix: String, limit: Int = 30) async throws -> [Food] {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty, limit > 0 else { return [] }

        let objectIDs: [NSManagedObjectID] = try await performBackgroundTask { context in
            let request = Self.makeObjectIDFetchRequest(limit: limit)
            request.predicate = Self.makePrefixPredicate(for: trimmedPrefix)
            return try context.fetch(request)
        }

        guard !objectIDs.isEmpty else { return [] }

        return try objectIDs.compactMap { objectID in
            try persistence.viewContext.existingObject(with: objectID) as? Food
        }
    }

    func food(by id: UUID) async throws -> Food? {
        let objectID: NSManagedObjectID? = try await performBackgroundTask { context in
            let request: NSFetchRequest<NSManagedObjectID> = NSFetchRequest(entityName: "Food")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            request.resultType = .managedObjectIDResultType
            return try context.fetch(request).first
        }

        guard let objectID else { return nil }
        return try persistence.viewContext.existingObject(with: objectID) as? Food
    }

    func countAll() async throws -> Int {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Food")
            return try context.count(for: request)
        }
    }
}

// MARK: - Private helpers

private extension FoodRepository {
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = persistence.newBackgroundContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let output = try block(context)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func makeObjectIDFetchRequest(limit: Int) -> NSFetchRequest<NSManagedObjectID> {
        let request = NSFetchRequest<NSManagedObjectID>(entityName: "Food")
        request.fetchLimit = limit
        request.resultType = .managedObjectIDResultType
        request.sortDescriptors = sortDescriptors
        return request
    }

    static func makePrefixPredicate(for prefix: String) -> NSPredicate {
        let format = "(name BEGINSWITH[cd] %@) OR (brand BEGINSWITH[cd] %@)"
        let base = NSPredicate(format: format, prefix, prefix)
        let notDeleted = NSPredicate(format: "isSoftDeleted == NO")
        return NSCompoundPredicate(andPredicateWithSubpredicates: [notDeleted, base])
    }

    static let sortDescriptors: [NSSortDescriptor] = [
        NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
        NSSortDescriptor(key: "brand", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
    ]
}

extension FoodRepositoryProtocol {
    func searchFoods(prefix: String) async throws -> [Food] {
        try await searchFoods(prefix: prefix, limit: 30)
    }
}
