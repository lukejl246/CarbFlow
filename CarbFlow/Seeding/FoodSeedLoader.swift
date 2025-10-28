import Foundation
import CoreData

enum FoodSeedLoader {
    private static let seedVersionKey = "cf_seed_food_version"
    private static let currentVersion = 2

    static func seedIfNeeded(persistence: PersistenceController = .shared) {
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: seedVersionKey)
        guard storedVersion < currentVersion else {
            print("[FoodSeed] Seed already applied v\(storedVersion)")
            analyticsEvent(status: "skipped", inserted: 0, updated: 0)
            return
        }

        guard let url = Bundle.main.url(forResource: "food_seed_v1", withExtension: "json", subdirectory: "Resources/Seeds") else {
            print("[FoodSeed] Seed file missing")
            analyticsEvent(status: "missing", inserted: 0, updated: 0)
            return
        }

        persistence.performBackgroundTask { context in
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = try decoder.decode([SeedFoodItem].self, from: data)
                let result = try apply(items: items, context: context)
                try context.save()
                defaults.set(currentVersion, forKey: seedVersionKey)
                print("[FoodSeed] Inserted: \(result.inserted), Updated: \(result.updated)")
                analyticsEvent(status: "applied", inserted: result.inserted, updated: result.updated)
            } catch {
                context.rollback()
                print("[FoodSeed] Failed: \(error)")
                analyticsEvent(status: "failed", inserted: 0, updated: 0)
            }
        }
    }

    private static func apply(items: [SeedFoodItem], context: NSManagedObjectContext) throws -> (inserted: Int, updated: Int) {
        guard !items.isEmpty else { return (0, 0) }

        let ids = items.map { $0.id }
        let fetch: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetch.predicate = NSPredicate(format: "id IN %@", ids)

        let existing = try context.fetch(fetch)
        var existingMap: [UUID: FoodItem] = [:]
        for item in existing {
            existingMap[item.id] = item
        }

        var inserted = 0
        var updated = 0

        for seed in items {
            if let managed = existingMap[seed.id] {
                update(managed, with: seed)
                updated += 1
            } else {
                _ = seed.makeManagedObject(in: context)
                inserted += 1
            }
        }

        return (inserted, updated)
    }

    private static func update(_ managed: FoodItem, with seed: SeedFoodItem) {
        managed.name = seed.name
        managed.brand = seed.brand
        managed.servingSize = seed.servingSizeGrams
        managed.carbs = seed.carbs
        managed.netCarbs = seed.netCarbs
        managed.fat = seed.fat
        managed.protein = seed.protein
        managed.kcal = seed.kcal
        managed.upc = seed.upc
        if let isVerified = seed.isVerified {
            managed.isVerified = isVerified
        }
        managed.internalReviewNote = seed.internalReviewNote
        managed.isUserCreated = seed.isUserCreated
        managed.createdAt = seed.createdAt
        managed.updatedAt = seed.updatedAt
    }

    private static func analyticsEvent(status: String, inserted: Int, updated: Int) {
        // Replace with real analytics call when available.
        print("[Analytics] food_seed status=\(status) inserted=\(inserted) updated=\(updated)")
    }
}

private struct SeedFoodItem: Decodable {
    let id: UUID
    let name: String
    let brand: String?
    let servingSizeGrams: Double?
    let carbs: Double
    let netCarbs: Double
    let fat: Double
    let protein: Double
    let kcal: Double
    let upc: String?
    let isVerified: Bool?
    let internalReviewNote: String?
    let isUserCreated: Bool
    let createdAt: Date
    let updatedAt: Date

    func makeManagedObject(in context: NSManagedObjectContext) -> FoodItem {
        FoodItem(context: context,
                 id: id,
                 name: name,
                 brand: brand,
                 servingSize: servingSizeGrams,
                 carbs: carbs,
                 netCarbs: netCarbs,
                 fat: fat,
                 protein: protein,
                 kcal: kcal,
                 upc: upc,
                 isVerified: isVerified ?? false,
                 internalReviewNote: internalReviewNote,
                 isUserCreated: isUserCreated,
                 createdAt: createdAt,
                 updatedAt: updatedAt)
    }
}
