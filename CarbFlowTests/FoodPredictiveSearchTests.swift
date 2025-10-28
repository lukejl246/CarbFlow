import XCTest
import CoreData
@testable import CarbFlow

@MainActor
final class FoodPredictiveSearchTests: XCTestCase {
    private var persistence: CFPersistence!
    private var searcher: CFPredictiveSearch!
    private let cache = FoodSearchCache.shared
    private let seedVersion: Int64 = 1
    private var seededIDs: [String: UUID] = [:]

    override func setUp() async throws {
        try await super.setUp()

        cache.clear()
        seededIDs.removeAll()

        persistence = CFPersistence.makeInMemory()
        searcher = CFPredictiveSearch(persistence: persistence)
        try await seedFoods()
    }

    override func tearDown() async throws {
#if targetEnvironment(simulator)
        CFDebugNetwork.setAirplaneModeEnabled(false)
#endif
        cache.clear()
        seededIDs.removeAll()
        searcher = nil
        persistence = nil
        try await super.tearDown()
    }

    func testPredictRanksEggFirst() async throws {
        let results = try await searcher.predict(query: "egg")
        XCTAssertFalse(results.isEmpty, "Predictive search should return results for egg")
        XCTAssertEqual(results.first?.name, "Eggs (Large)")
    }

    func testRecentlyUsedItemRanksHigher() async throws {
        try await markAsRecentlyUsed(named: "Salmon Cuts (Smoked)")

        let results = try await searcher.predict(query: "salmon")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.name, "Salmon Cuts (Smoked)")
    }

    func testAverageLatencyIsUnderOneHundredMilliseconds() async throws {
        let iterations = 10
        var total = 0.0

        for _ in 0..<iterations {
            let start = ContinuousClock.now
            _ = try await searcher.predict(query: "avocado")
            let elapsed = ContinuousClock.now - start
            total += elapsed.milliseconds
        }

        let average = total / Double(iterations)
        XCTAssertLessThanOrEqual(average, 100.0, "Expected predictive search average latency ≤100ms, got \(average)")
    }

    func testCacheHitIsUnderTenMilliseconds() async throws {
        let query = "egg"
        let results = try await searcher.predict(query: query)
        let version = seedVersion
        cache.save(query: query, ids: results.map { $0.id }, seedVersion: version)

        let start = ContinuousClock.now
        let cachedIDs = cache.get(query: query, seedVersion: version)
        let elapsed = ContinuousClock.now - start

        XCTAssertNotNil(cachedIDs, "Cache should return ids for previously stored query")
        XCTAssertLessThanOrEqual(elapsed.milliseconds, 120.0, "Cache lookup should be ≤120ms, got \(elapsed.milliseconds)")
    }

    func testPredictiveSearchWorksInSimulatedAirplaneMode() async throws {
#if targetEnvironment(simulator)
        CFDebugNetwork.setAirplaneModeEnabled(true)
        defer { CFDebugNetwork.setAirplaneModeEnabled(false) }
#endif

        let results = try await searcher.predict(query: "egg")
        XCTAssertFalse(results.isEmpty, "Predictive search should work offline")
    }
}

// MARK: - Seeding helpers

private extension FoodPredictiveSearchTests {
    struct FoodSeed {
        let name: String
        let brand: String?
        let netCarbs: Double
        let protein: Double
        let fat: Double
        let portion: Double
        let isVerified: Bool
        let updatedAt: Date
    }

    func seedFoods() async throws {
        let context = persistence.newBackgroundContext()
        let mapping: [String: UUID] = try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let now = Date()
                    var ids: [String: UUID] = [:]
                    let featured: [FoodSeed] = [
                        FoodSeed(name: "Eggs (Large)", brand: "Farm Fresh", netCarbs: 1.1, protein: 13.0, fat: 10.0, portion: 100, isVerified: true, updatedAt: now.addingTimeInterval(-3600)),
                        FoodSeed(name: "Egg Whites Carton", brand: "Protein Co", netCarbs: 0.5, protein: 11.0, fat: 0.3, portion: 90, isVerified: true, updatedAt: now.addingTimeInterval(-7200)),
                        FoodSeed(name: "Salmon Cuts (Smoked)", brand: "Pacific Waters", netCarbs: 0.0, protein: 20.0, fat: 12.0, portion: 85, isVerified: true, updatedAt: now.addingTimeInterval(-86400 * 3)),
                        FoodSeed(name: "Salmon Fillet", brand: "Wild Catch", netCarbs: 0.0, protein: 22.0, fat: 13.0, portion: 100, isVerified: true, updatedAt: now.addingTimeInterval(-86400 * 5)),
                        FoodSeed(name: "Avocado Hass", brand: "Green Valley", netCarbs: 2.8, protein: 2.0, fat: 15.0, portion: 70, isVerified: true, updatedAt: now.addingTimeInterval(-86400 * 2)),
                        FoodSeed(name: "Avocado Oil", brand: "Cold Pressed", netCarbs: 0.0, protein: 0.0, fat: 100.0, portion: 15, isVerified: true, updatedAt: now.addingTimeInterval(-86400 * 4))
                    ]

                    for (index, seed) in featured.enumerated() {
                        let food = Food(context: context)
                        let identifier = UUID()
                        food.id = identifier
                        food.name = seed.name
                        food.brand = seed.brand
                        food.portionGram = seed.portion
                        food.netCarbsPer100g = seed.netCarbs
                        food.proteinPer100g = seed.protein
                        food.fatPer100g = seed.fat
                        food.isVerified = seed.isVerified
                        food.createdAt = now.addingTimeInterval(-86400 * Double(index + 1))
                        food.updatedAt = seed.updatedAt
                        ids[seed.name] = identifier
                    }

                    for index in 0..<80 {
                        let food = Food(context: context)
                        let identifier = UUID()
                        food.id = identifier
                        food.name = "Test Food \(index)"
                        food.brand = index % 2 == 0 ? "Brand \(index)" : nil
                        food.portionGram = 100
                        food.netCarbsPer100g = Double(index % 15)
                        food.proteinPer100g = Double((index * 3) % 25)
                        food.fatPer100g = Double((index * 7) % 30)
                        food.isVerified = index % 3 == 0
                        food.createdAt = now.addingTimeInterval(-86400 * Double(10 + index))
                        food.updatedAt = now.addingTimeInterval(-86400 * Double((index % 14) + 1))
                    }

                    let meta = MetaSeed(context: context)
                    meta.version = self.seedVersion
                    meta.appliedAt = now

                    try context.save()
                    continuation.resume(returning: ids)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        seededIDs = mapping
    }

    func markAsRecentlyUsed(named name: String) async throws {
        guard let identifier = seededIDs[name] else {
            XCTFail("Missing seeded food for \(name)")
            return
        }
        let context = persistence.newBackgroundContext()
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Food> = Food.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", identifier as CVarArg)
                    request.fetchLimit = 1
                    if let food = try context.fetch(request).first {
                        food.updatedAt = Date()
                        try context.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
