import CoreData

extension Food {
    /// Ensures there is a `FoodItem` representation of this `Food` in the supplied context.
    /// - Parameter context: The Core Data context where the `FoodItem` should live.
    /// - Returns: A managed `FoodItem` linked to this food's identifier.
    /// - Note: Callers are responsible for saving the context after receiving the item.
    func ensureFoodItem(in context: NSManagedObjectContext) throws -> FoodItem {
        guard let foodID = id else {
            throw NSError(domain: "CarbFlow.UserFood", code: 1, userInfo: [NSLocalizedDescriptionKey: "Food missing identifier"])
        }

        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "id == %@", foodID as CVarArg)

        if let existing = try context.fetch(fetchRequest).first {
            update(foodItem: existing)
            return existing
        }

        let portion = max(portionGram, 1.0)
        let scale = portion / 100.0

        let netCarbsPerPortion = netCarbsPer100g * scale
        let proteinPerPortion = proteinPer100g * scale
        let fatPerPortion = fatPer100g * scale
        let carbsPerPortion = netCarbsPerPortion // TODO: capture total carbs when available.
        let calories = (netCarbsPerPortion * 4) + (proteinPerPortion * 4) + (fatPerPortion * 9)

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)

        let newItem = FoodItem(
            context: context,
            id: foodID,
            name: name ?? "",
            brand: brand,
            servingSize: portion,
            carbs: carbsPerPortion,
            netCarbs: netCarbsPerPortion,
            fat: fatPerPortion,
            protein: proteinPerPortion,
            kcal: calories,
            upc: upc,
            isVerified: isVerified,
            internalReviewNote: trimmedNotes?.isEmpty == true ? nil : trimmedNotes,
            isUserCreated: isUserCreated,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )

        return newItem
    }

    private func update(foodItem: FoodItem) {
        let portion = max(portionGram, 1.0)
        let scale = portion / 100.0

        let netCarbsPerPortion = netCarbsPer100g * scale
        let proteinPerPortion = proteinPer100g * scale
        let fatPerPortion = fatPer100g * scale
        let carbsPerPortion = netCarbsPerPortion
        let calories = (netCarbsPerPortion * 4) + (proteinPerPortion * 4) + (fatPerPortion * 9)

        foodItem.name = name ?? foodItem.name
        foodItem.brand = brand
        foodItem.servingSize = portion
        foodItem.netCarbs = netCarbsPerPortion
        foodItem.carbs = carbsPerPortion
        foodItem.protein = proteinPerPortion
        foodItem.fat = fatPerPortion
        foodItem.kcal = calories
        foodItem.upc = upc
        foodItem.isVerified = isVerified
        foodItem.isUserCreated = isUserCreated
        foodItem.internalReviewNote = {
            let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == true ? nil : trimmed
        }()
        if let createdAt {
            foodItem.createdAt = createdAt
        }
        if let updatedAt {
            foodItem.updatedAt = updatedAt
        }
    }
}
