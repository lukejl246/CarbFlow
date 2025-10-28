import CoreData

final class FoodStore {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func all(limit: Int = 100) -> [FoodItem] {
        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        return (try? context.fetch(request)) ?? []
    }

    func search(_ text: String, limit: Int = 50) -> [FoodItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        request.fetchLimit = limit
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "name CONTAINS[cd] %@", trimmed),
            NSPredicate(format: "brand CONTAINS[cd] %@", trimmed)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        let results = (try? context.fetch(request)) ?? []
        analyticsEvent(name: "search_query", params: ["query": trimmed, "result_count": results.count])
        return results
    }

    func item(forUPC upc: String) -> FoodItem? {
        let trimmed = upc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let digitsOnly = trimmed.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return nil }

        var candidates: Set<String> = [trimmed, digitsOnly]
        if digitsOnly.count == 12 {
            candidates.insert("0" + digitsOnly)
        } else if digitsOnly.count == 13, digitsOnly.hasPrefix("0") {
            candidates.insert(String(digitsOnly.dropFirst()))
        }

        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "upc IN %@", Array(candidates))
        return try? context.fetch(request).first
    }

    private func analyticsEvent(name: String, params: [String: Any]) {
        #if DEBUG
        print("[Analytics] \(name) \(params)")
        #endif
    }
}
