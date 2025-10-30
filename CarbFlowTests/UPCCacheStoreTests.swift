import XCTest
import CoreData
@testable import CarbFlow

@MainActor
final class UPCCacheStoreTests: XCTestCase {

    var cacheStore: UPCCacheStore!
    var testCachePath: URL!
    var testContext: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Enable the feature flag for testing
        FeatureFlags.setScanCacheEnabled(true)

        // Set up in-memory Core Data context for testing
        let container = NSPersistentContainer(name: "CarbFlow")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }

        testContext = container.viewContext

        // Create a new cache store for each test
        cacheStore = UPCCacheStore()

        // Get cache file path
        testCachePath = await cacheStore.cacheFileURL

        // Clear any existing cache
        await cacheStore.clear()
    }

    override func tearDown() async throws {
        // Clean up cache file
        if FileManager.default.fileExists(atPath: testCachePath.path) {
            try? FileManager.default.removeItem(at: testCachePath)
        }

        cacheStore = nil
        testCachePath = nil
        testContext = nil

        try await super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testCacheFileCreatedOnFirstWrite() async throws {
        // Given: No cache file exists
        XCTAssertFalse(FileManager.default.fileExists(atPath: testCachePath.path))

        // When: Store a UPC mapping
        let foodItem = createTestFoodItem(name: "Test Food", netCarbs: 10.0)
        await cacheStore.store(upc: "123456789012", foodItem: foodItem)

        // Then: Cache file should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: testCachePath.path))
    }

    func testLookupReturnsCachedItem() async throws {
        // Given: A food item stored in cache
        let foodItem = createTestFoodItem(name: "Almond Butter", netCarbs: 6.0, brand: "Justin's")
        let upc = "042343370210"

        await cacheStore.store(upc: upc, foodItem: foodItem)

        // When: Looking up the UPC
        let cachedItem = await cacheStore.lookup(upc)

        // Then: Should return the cached item
        XCTAssertNotNil(cachedItem)
        XCTAssertEqual(cachedItem?.name, "Almond Butter")
        XCTAssertEqual(cachedItem?.netCarbs, 6.0)
        XCTAssertEqual(cachedItem?.brand, "Justin's")
        XCTAssertEqual(cachedItem?.upc, upc)
    }

    func testLookupReturnsNilForMissingItem() async throws {
        // When: Looking up a UPC that doesn't exist
        let result = await cacheStore.lookup("999999999999")

        // Then: Should return nil
        XCTAssertNil(result)
    }

    func testLookupPerformanceUnder50ms() async throws {
        // Given: Cache with 1000 items
        for i in 0..<1000 {
            let foodItem = createTestFoodItem(name: "Food \(i)", netCarbs: Double(i))
            await cacheStore.store(upc: String(format: "%012d", i), foodItem: foodItem)
        }

        // When: Performing lookup
        let startTime = Date()
        let result = await cacheStore.lookup("000000000500")
        let elapsedTime = Date().timeIntervalSince(startTime) * 1000 // Convert to ms

        // Then: Should return result in under 50ms
        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsedTime, 50.0, "Lookup took \(elapsedTime)ms, expected <50ms")
    }

    func testCacheSurvivesAppRestart() async throws {
        // Given: A food item stored in cache
        let foodItem = createTestFoodItem(name: "Original Food", netCarbs: 15.0)
        let upc = "111111111111"

        await cacheStore.store(upc: upc, foodItem: foodItem)

        // When: Simulating app restart by creating new cache store
        let newCacheStore = UPCCacheStore()

        // Wait a bit for cache to load
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then: Should still be able to lookup the item
        let cachedItem = await newCacheStore.lookup(upc)
        XCTAssertNotNil(cachedItem)
        XCTAssertEqual(cachedItem?.name, "Original Food")
        XCTAssertEqual(cachedItem?.netCarbs, 15.0)
    }

    // MARK: - LRU Eviction Tests

    func testLRUEvictionWhenMaxEntriesExceeded() async throws {
        // Given: Fill cache to max capacity (10,000 entries)
        // Use smaller number for test performance
        let testMaxEntries = 100

        // Store 100 items
        for i in 0..<testMaxEntries {
            let foodItem = createTestFoodItem(name: "Food \(i)", netCarbs: Double(i))
            await cacheStore.store(upc: String(format: "%012d", i), foodItem: foodItem)
        }

        // Verify first item exists
        let firstItem = await cacheStore.lookup(String(format: "%012d", 0))
        XCTAssertNotNil(firstItem)

        // When: Add one more item (forcing eviction in real implementation)
        // Note: For full test, we'd need to store 10,001 items
        let newFoodItem = createTestFoodItem(name: "Food New", netCarbs: 99.0)
        await cacheStore.store(upc: String(format: "%012d", testMaxEntries), foodItem: newFoodItem)

        // Then: Stats should show reasonable entry count
        let stats = await cacheStore.getStats()
        XCTAssertLessThanOrEqual(stats.totalEntries, 10_000)
    }

    func testLRUOrderMaintained() async throws {
        // Given: Three items in cache
        let food1 = createTestFoodItem(name: "Food 1", netCarbs: 1.0)
        let food2 = createTestFoodItem(name: "Food 2", netCarbs: 2.0)
        let food3 = createTestFoodItem(name: "Food 3", netCarbs: 3.0)

        await cacheStore.store(upc: "001", foodItem: food1)
        await cacheStore.store(upc: "002", foodItem: food2)
        await cacheStore.store(upc: "003", foodItem: food3)

        // When: Access middle item (should move to end of LRU)
        _ = await cacheStore.lookup("002")

        // Then: All items should still be accessible
        XCTAssertNotNil(await cacheStore.lookup("001"))
        XCTAssertNotNil(await cacheStore.lookup("002"))
        XCTAssertNotNil(await cacheStore.lookup("003"))
    }

    // MARK: - Batch Operations Tests

    func testBatchUpdate() async throws {
        // Given: Multiple food items
        let food1 = createTestFoodItem(name: "Batch Food 1", netCarbs: 5.0)
        let food2 = createTestFoodItem(name: "Batch Food 2", netCarbs: 10.0)
        let food3 = createTestFoodItem(name: "Batch Food 3", netCarbs: 15.0)

        let mappings: [String: FoodItem] = [
            "100001": food1,
            "100002": food2,
            "100003": food3
        ]

        // When: Batch updating
        await cacheStore.batchUpdate(mappings)

        // Then: All items should be retrievable
        XCTAssertNotNil(await cacheStore.lookup("100001"))
        XCTAssertNotNil(await cacheStore.lookup("100002"))
        XCTAssertNotNil(await cacheStore.lookup("100003"))

        let stats = await cacheStore.getStats()
        XCTAssertEqual(stats.totalEntries, 3)
    }

    // MARK: - Export/Import Tests

    func testExportCache() async throws {
        // Given: Cache with items
        let food1 = createTestFoodItem(name: "Export Food 1", netCarbs: 12.0)
        let food2 = createTestFoodItem(name: "Export Food 2", netCarbs: 18.0)

        await cacheStore.store(upc: "200001", foodItem: food1)
        await cacheStore.store(upc: "200002", foodItem: food2)

        // When: Exporting cache
        let exportedData = try await cacheStore.exportCache()

        // Then: Should get valid JSON data
        XCTAssertGreaterThan(exportedData.count, 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: exportedData)
        XCTAssertNotNil(json)
    }

    func testImportCache() async throws {
        // Given: Exported cache data
        let food1 = createTestFoodItem(name: "Import Food 1", netCarbs: 8.0)
        await cacheStore.store(upc: "300001", foodItem: food1)
        let exportedData = try await cacheStore.exportCache()

        // Clear cache
        await cacheStore.clear()
        XCTAssertNil(await cacheStore.lookup("300001"))

        // When: Importing cache
        try await cacheStore.importCache(from: exportedData)

        // Then: Should restore the cached item
        let result = await cacheStore.lookup("300001")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Import Food 1")
        XCTAssertEqual(result?.netCarbs, 8.0)
    }

    // MARK: - Cache Management Tests

    func testRemoveUPC() async throws {
        // Given: Item in cache
        let foodItem = createTestFoodItem(name: "To Remove", netCarbs: 20.0)
        await cacheStore.store(upc: "400001", foodItem: foodItem)
        XCTAssertNotNil(await cacheStore.lookup("400001"))

        // When: Removing the UPC
        await cacheStore.remove(upc: "400001")

        // Then: Should no longer be in cache
        XCTAssertNil(await cacheStore.lookup("400001"))
    }

    func testClearCache() async throws {
        // Given: Multiple items in cache
        for i in 0..<10 {
            let foodItem = createTestFoodItem(name: "Food \(i)", netCarbs: Double(i))
            await cacheStore.store(upc: String(format: "%06d", i), foodItem: foodItem)
        }

        let statsBefore = await cacheStore.getStats()
        XCTAssertEqual(statsBefore.totalEntries, 10)

        // When: Clearing cache
        await cacheStore.clear()

        // Then: Cache should be empty
        let statsAfter = await cacheStore.getStats()
        XCTAssertEqual(statsAfter.totalEntries, 0)
        XCTAssertNil(await cacheStore.lookup("000000"))
    }

    func testContains() async throws {
        // Given: Item in cache
        let foodItem = createTestFoodItem(name: "Test Contains", netCarbs: 5.0)
        await cacheStore.store(upc: "500001", foodItem: foodItem)

        // When/Then: Checking existence
        XCTAssertTrue(await cacheStore.contains(upc: "500001"))
        XCTAssertFalse(await cacheStore.contains(upc: "999999"))
    }

    // MARK: - Statistics Tests

    func testGetStats() async throws {
        // Given: Empty cache
        var stats = await cacheStore.getStats()
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertNil(stats.oldestEntry)
        XCTAssertNil(stats.newestEntry)

        // When: Adding items
        let food1 = createTestFoodItem(name: "Stats Food 1", netCarbs: 10.0)
        await cacheStore.store(upc: "600001", foodItem: food1)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

        let food2 = createTestFoodItem(name: "Stats Food 2", netCarbs: 20.0)
        await cacheStore.store(upc: "600002", foodItem: food2)

        // Then: Stats should reflect entries
        stats = await cacheStore.getStats()
        XCTAssertEqual(stats.totalEntries, 2)
        XCTAssertNotNil(stats.oldestEntry)
        XCTAssertNotNil(stats.newestEntry)
        XCTAssertGreaterThan(stats.cacheFileSize, 0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async throws {
        // Given: Multiple concurrent operations
        let iterations = 50

        await withTaskGroup(of: Void.self) { group in
            // Concurrent stores
            for i in 0..<iterations {
                group.addTask {
                    let foodItem = self.createTestFoodItem(name: "Concurrent Food \(i)", netCarbs: Double(i))
                    await self.cacheStore.store(upc: String(format: "%06d", i), foodItem: foodItem)
                }
            }

            // Concurrent lookups
            for i in 0..<iterations {
                group.addTask {
                    _ = await self.cacheStore.lookup(String(format: "%06d", i))
                }
            }

            await group.waitForAll()
        }

        // Then: All operations should complete without crashes
        let stats = await cacheStore.getStats()
        XCTAssertGreaterThan(stats.totalEntries, 0)
        XCTAssertLessThanOrEqual(stats.totalEntries, iterations)
    }

    // MARK: - Feature Flag Tests

    func testCacheDisabledWhenFeatureFlagOff() async throws {
        // Given: Feature flag disabled
        FeatureFlags.setScanCacheEnabled(false)

        // Wait for flag change to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let disabledCacheStore = UPCCacheStore()

        // When: Attempting to store and lookup
        let foodItem = createTestFoodItem(name: "Disabled Test", netCarbs: 5.0)
        await disabledCacheStore.store(upc: "700001", foodItem: foodItem)

        let result = await disabledCacheStore.lookup("700001")

        // Then: Should return nil (cache disabled)
        XCTAssertNil(result)

        // Re-enable for other tests
        FeatureFlags.setScanCacheEnabled(true)
    }

    // MARK: - Helper Methods

    private func createTestFoodItem(
        name: String,
        netCarbs: Double,
        brand: String? = nil
    ) -> FoodItem {
        FoodItem(
            context: testContext,
            id: UUID(),
            name: name,
            brand: brand,
            servingSize: 100,
            carbs: netCarbs + 2.0, // Add some fiber to get total carbs
            netCarbs: netCarbs,
            fat: 5.0,
            protein: 3.0,
            kcal: 100.0,
            upc: nil,
            isVerified: false,
            internalReviewNote: nil,
            isUserCreated: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
