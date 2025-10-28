import CoreData
import Foundation

struct FoodPrediction: Equatable {
    let id: UUID
    let name: String
    let brand: String?
    let netCarbsPer100g: Double
    let isVerified: Bool
    let score: Double
}

final class CFPredictiveSearch {
    private let persistence: CFPersistence
    private let recencyWindow: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init(persistence: CFPersistence) {
        self.persistence = persistence
    }

    func predict(query: String, limit: Int = 30) async throws -> [FoodPrediction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else {
            return []
        }

        let context = await MainActor.run { persistence.newBackgroundContext() }

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Food> = Food.fetchRequest()
                    request.fetchLimit = limit * 3
                    request.predicate = Self.makePredicate(for: trimmed)
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                    ]

                    let foods = try context.fetch(request)
                    let now = Date()
                    let predictions: [FoodPrediction] = foods.compactMap { food in
                        guard
                            let identifier = food.id,
                            let name = food.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                            !name.isEmpty
                        else {
                            return nil
                        }

                        let brand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let matchScore = Self.matchScore(for: trimmed, name: name, brand: brand)
                        guard matchScore > 0 else { return nil }

                        let recency = Self.recencyBoost(updatedAt: food.updatedAt, now: now, window: self.recencyWindow)
                        let verifiedBoost = food.isVerified ? 0.1 : 0.0
                        let score = matchScore + recency + verifiedBoost

                        return FoodPrediction(
                            id: identifier,
                            name: name,
                            brand: brand?.isEmpty == false ? brand : nil,
                            netCarbsPer100g: food.netCarbsPer100g,
                            isVerified: food.isVerified,
                            score: score
                        )
                    }

                    let sorted = predictions
                        .sorted { lhs, rhs in
                            if abs(lhs.score - rhs.score) > 0.0001 {
                                return lhs.score > rhs.score
                            }
                            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                        }
                        .prefix(limit)

                    continuation.resume(returning: Array(sorted))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension CFPredictiveSearch {
    static func makePredicate(for query: String) -> NSPredicate {
        NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "name BEGINSWITH[cd] %@", query),
            NSPredicate(format: "brand BEGINSWITH[cd] %@", query),
            NSPredicate(format: "name CONTAINS[cd] %@", query),
            NSPredicate(format: "brand CONTAINS[cd] %@", query)
        ])
    }

    static func matchScore(for query: String, name: String, brand: String?) -> Double {
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let normalizedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let normalizedBrand = brand?.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if normalizedName.hasPrefix(normalizedQuery) {
            return 1.0
        }

        if let normalizedBrand, normalizedBrand.hasPrefix(normalizedQuery) {
            return 0.9
        }

        if normalizedName.contains(normalizedQuery) {
            return 0.7
        }

        if let normalizedBrand, normalizedBrand.contains(normalizedQuery) {
            return 0.6
        }

        let fuzzyNameScore = fuzzyScore(query: normalizedQuery, target: normalizedName)
        if fuzzyNameScore > 0.0 {
            return fuzzyNameScore
        }

        if let normalizedBrand {
            let fuzzyBrandScore = fuzzyScore(query: normalizedQuery, target: normalizedBrand)
            if fuzzyBrandScore > 0.0 {
                return max(0.3, fuzzyBrandScore * 0.8)
            }
        }

        return 0.0
    }

    static func recencyBoost(updatedAt: Date?, now: Date, window: TimeInterval) -> Double {
        guard let updatedAt else { return 0.0 }
        let distance = now.timeIntervalSince(updatedAt)
        guard distance >= 0, distance <= window else { return 0.0 }
        let ratio = max(0.0, 1.0 - (distance / window))
        return 0.2 * ratio
    }

    static func fuzzyScore(query: String, target: String) -> Double {
        guard !query.isEmpty, !target.isEmpty else { return 0.0 }

        let distance = levenshteinDistance(query, target)
        let maxLength = max(query.count, target.count)
        guard maxLength > 0 else { return 0.0 }

        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return similarity >= 0.6 ? 0.5 * similarity : 0.0
    }

    static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let lhsCount = lhsChars.count
        let rhsCount = rhsChars.count

        var distances = Array(repeating: Array(repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

        for i in 0...lhsCount {
            distances[i][0] = i
        }

        for j in 0...rhsCount {
            distances[0][j] = j
        }

        for i in 1...lhsCount {
            for j in 1...rhsCount {
                if lhsChars[i - 1] == rhsChars[j - 1] {
                    distances[i][j] = distances[i - 1][j - 1]
                } else {
                    distances[i][j] = min(
                        distances[i - 1][j] + 1,
                        distances[i][j - 1] + 1,
                        distances[i - 1][j - 1] + 1
                    )
                }
            }
        }

        return distances[lhsCount][rhsCount]
    }
}
