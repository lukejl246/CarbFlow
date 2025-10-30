import CoreData
import Foundation

struct NewUserFoodInput: Codable, Sendable {
    var name: String
    var brand: String?
    var servingSizeValue: Double?
    var servingSizeUnit: String?
    var netCarbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var notes: String?
    var upc: String?
}

enum UserFoodRepositoryError: Error {
    case duplicate
    case notFound
}

@MainActor
final class UserFoodRepository {
    private let persistence: CFPersistence

    init(persistence: CFPersistence) {
        self.persistence = persistence
    }

    func create(_ input: NewUserFoodInput) async throws -> Food {
        let normalizedName = normaliseName(input.name)
        guard !normalizedName.isEmpty else { throw FoodValidationError.emptyName }

        let normalizedBrand = input.brand
            .map(normaliseName)
            .flatMap { $0.isEmpty ? nil : $0 }
        let slug = makeSlug(name: normalizedName, brand: normalizedBrand)
        guard !slug.isEmpty else { throw FoodValidationError.emptyName }

        guard validateMacros(netCarbsPer100g: input.netCarbsPer100g,
                             protein: input.proteinPer100g,
                             fat: input.fatPer100g) else {
            throw FoodValidationError.invalidMacros
        }

        try validateServingValue(input.servingSizeValue)

        let now = Date()
        let objectID: NSManagedObjectID = try await performBackgroundTask { context in
            try self.ensureNoDuplicate(slug: slug, context: context, excluding: nil)

            let food = Food(context: context)
            food.id = UUID()
            food.name = normalizedName
            food.brand = normalizedBrand
            food.slug = slug
            food.isVerified = false
            food.isUserCreated = true
            food.isSoftDeleted = false
            food.source = "user"
            food.createdBy = "local"
            food.createdAt = now
            food.updatedAt = now
            food.netCarbsPer100g = input.netCarbsPer100g
            food.proteinPer100g = input.proteinPer100g
            food.fatPer100g = input.fatPer100g
            food.cfServingSizeValue = input.servingSizeValue

            let trimmedUnit = input.servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines)
            food.servingSizeUnit = trimmedUnit?.isEmpty == true ? nil : trimmedUnit
            food.notes = input.notes

            let trimmedUPC = input.upc?.trimmingCharacters(in: .whitespacesAndNewlines)
            food.upc = trimmedUPC?.isEmpty == true ? nil : trimmedUPC

            // default portion weight for user foods when not supplied
            food.portionGram = 100
            self.updatePortionGramIfPossible(for: food)

            try context.obtainPermanentIDs(for: [food])
            try context.save()
            return food.objectID
        }

        guard let food = try persistence.viewContext.existingObject(with: objectID) as? Food else {
            throw UserFoodRepositoryError.notFound
        }
        return food
    }

    func update(id: NSManagedObjectID, mutate: @escaping (Food) -> Void) async throws {
        let now = Date()
        try await performBackgroundTask { [self] context in
            guard let food = try context.existingObject(with: id) as? Food else {
                throw UserFoodRepositoryError.notFound
            }

            guard food.isUserCreated, food.isSoftDeleted == false else {
                throw UserFoodRepositoryError.notFound
            }

            mutate(food)

            try self.normalizeAndValidate(food: food, context: context, excluding: food.objectID)
            food.updatedAt = now

            try context.save()
        }
    }

    func update(id: NSManagedObjectID, with patch: FoodPatch) async throws {
        let now = Date()
        try await performBackgroundTask { [self] context in
            guard let food = try context.existingObject(with: id) as? Food else {
                throw UserFoodRepositoryError.notFound
            }

            guard food.isUserCreated, food.isSoftDeleted == false else {
                throw UserFoodRepositoryError.notFound
            }

            apply(patch, to: food)

            try self.normalizeAndValidate(food: food, context: context, excluding: food.objectID)

            if patch.updatedAt == nil {
                food.updatedAt = now
            }

            try context.save()
        }
    }

    func softDelete(id: NSManagedObjectID) async throws {
        try await performBackgroundTask { context in
            guard let food = try context.existingObject(with: id) as? Food else {
                throw UserFoodRepositoryError.notFound
            }

            guard food.isUserCreated else {
                throw UserFoodRepositoryError.notFound
            }

            food.isSoftDeleted = true
            food.updatedAt = Date()
            try context.save()
        }
    }

    func hardPurgeDeleted() async throws {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<NSManagedObjectID> = NSFetchRequest(entityName: "Food")
            request.predicate = NSPredicate(format: "isSoftDeleted == YES")
            request.resultType = .managedObjectIDResultType

            let objectIDs = try context.fetch(request)
            guard !objectIDs.isEmpty else { return }

            for objectID in objectIDs {
                if let object = try? context.existingObject(with: objectID) {
                    context.delete(object)
                }
            }

            try context.save()
        }
    }
}

// MARK: - Helpers

private extension UserFoodRepository {
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = persistence.newBackgroundContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func ensureNoDuplicate(slug: String, context: NSManagedObjectContext, excluding objectID: NSManagedObjectID?) throws {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Food")
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isUserCreated == YES"),
            NSPredicate(format: "isSoftDeleted == NO"),
            NSPredicate(format: "slug == %@", slug)
        ]

        if let objectID {
            predicates.append(NSPredicate(format: "SELF != %@", objectID))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1

        let count = try context.count(for: request)
        if count > 0 {
            throw UserFoodRepositoryError.duplicate
        }
    }

    func normalizeAndValidate(food: Food, context: NSManagedObjectContext, excluding objectID: NSManagedObjectID?) throws {
        let normalizedName = normaliseName(food.name ?? "")
        guard !normalizedName.isEmpty else { throw FoodValidationError.emptyName }

        let normalizedBrand = food.brand
            .map(normaliseName)
            .flatMap { $0.isEmpty ? nil : $0 }
        let slug = makeSlug(name: normalizedName, brand: normalizedBrand)
        guard !slug.isEmpty else { throw FoodValidationError.emptyName }

        guard validateMacros(netCarbsPer100g: food.netCarbsPer100g,
                             protein: food.proteinPer100g,
                             fat: food.fatPer100g) else {
            throw FoodValidationError.invalidMacros
        }

        try validateServingValue(food.cfServingSizeValue)

        food.name = normalizedName
        food.brand = normalizedBrand
        food.slug = slug
        let trimmedUnit = food.servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines)
        food.servingSizeUnit = trimmedUnit?.isEmpty == true ? nil : trimmedUnit

        self.updatePortionGramIfPossible(for: food)

        try self.ensureNoDuplicate(slug: slug, context: context, excluding: objectID)
    }

    func updatePortionGramIfPossible(for food: Food) {
        guard let value = food.cfServingSizeValue,
              let unit = food.servingSizeUnit?.lowercased(),
              let grams = servingInGrams(value: value, unit: unit) else { return }
        food.portionGram = grams
    }

    func validateServingValue(_ value: Double?) throws {
        guard let value else { return }
        guard value.isFinite, value > 0 else {
            throw FoodValidationError.invalidServing
        }
    }
}

private extension UserFoodRepository {
    func apply(_ patch: FoodPatch, to food: Food) {
        if let name = patch.name {
            food.name = normaliseName(name)
        }

        if let brand = patch.brand {
            switch brand {
            case .set(let value):
                let normalized = normaliseName(value)
                food.brand = normalized.isEmpty ? nil : normalized
            case .clear:
                food.brand = nil
            }
        }

        if let servingSizeValue = patch.servingSizeValue {
            switch servingSizeValue {
            case .set(let value):
                food.cfServingSizeValue = value
            case .clear:
                food.cfServingSizeValue = nil
            }
        }

        if let servingSizeUnit = patch.servingSizeUnit {
            switch servingSizeUnit {
            case .set(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                food.servingSizeUnit = trimmed.isEmpty ? nil : trimmed
            case .clear:
                food.servingSizeUnit = nil
            }
        }

        if let netCarbsPer100g = patch.netCarbsPer100g {
            food.netCarbsPer100g = netCarbsPer100g
        }

        if let proteinPer100g = patch.proteinPer100g {
            food.proteinPer100g = proteinPer100g
        }

        if let fatPer100g = patch.fatPer100g {
            food.fatPer100g = fatPer100g
        }

        if let notes = patch.notes {
            switch notes {
            case .set(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                food.notes = trimmed.isEmpty ? nil : trimmed
            case .clear:
                food.notes = nil
            }
        }

        if let upc = patch.upc {
            switch upc {
            case .set(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                food.upc = trimmed.isEmpty ? nil : trimmed
            case .clear:
                food.upc = nil
            }
        }

        if let updatedAt = patch.updatedAt {
            food.updatedAt = updatedAt
        }
    }
}

private extension Food {
    var cfServingSizeValue: Double? {
        get { value(forKey: "servingSizeValue") as? Double }
        set { setValue(newValue, forKey: "servingSizeValue") }
    }
}
