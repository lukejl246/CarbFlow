import Foundation
import CoreData

// MARK: - Cache Verification Helper

extension UPCCacheStore {

    /// Simple verification method for testing cache functionality
    /// This can be called from anywhere in the app for manual verification
    @MainActor
    static func verify(context: NSManagedObjectContext) async {
        print("=== UPC Cache Store Verification ===")

        let cache = UPCCacheStore.shared

        // Test 1: Cache file location
        print("\n1. Cache file location:")
        print("   Path: \(cache.cacheFileURL.path)")

        // Test 2: Store a test item
        print("\n2. Storing test item...")
        let testFood = FoodItem(
            context: context,
            id: UUID(),
            name: "Test Almond Butter",
            brand: "Test Brand",
            servingSize: 100,
            carbs: 8.0,
            netCarbs: 6.0,
            fat: 16.0,
            protein: 7.0,
            kcal: 190.0,
            upc: "123456789012",
            isVerified: false,
            internalReviewNote: nil,
            isUserCreated: true
        )

        await cache.store(upc: "123456789012", foodItem: testFood)
        print("   ✓ Stored test item")

        // Test 3: Lookup test item
        print("\n3. Looking up test item...")
        let startTime = Date()
        let cachedItem = await cache.lookup("123456789012")
        let elapsedMs = Date().timeIntervalSince(startTime) * 1000

        if let cachedItem = cachedItem {
            print("   ✓ Found cached item:")
            print("     Name: \(cachedItem.name)")
            print("     Brand: \(cachedItem.brand ?? "N/A")")
            print("     Net Carbs: \(cachedItem.netCarbs)g")
            print("     Lookup time: \(String(format: "%.2f", elapsedMs))ms")
        } else {
            print("   ✗ Failed to find cached item")
        }

        // Test 4: Cache statistics
        print("\n4. Cache statistics:")
        let stats = await cache.getStats()
        print("   Total entries: \(stats.totalEntries)")
        print("   Cache file size: \(stats.cacheFileSize) bytes")
        if let oldest = stats.oldestEntry {
            print("   Oldest entry: \(oldest)")
        }
        if let newest = stats.newestEntry {
            print("   Newest entry: \(newest)")
        }

        // Test 5: Cache persistence check
        print("\n5. Checking cache file exists...")
        if FileManager.default.fileExists(atPath: cache.cacheFileURL.path) {
            print("   ✓ Cache file exists")
        } else {
            print("   ✗ Cache file does not exist")
        }

        // Test 6: Batch operations
        print("\n6. Testing batch operations...")
        var batchItems: [String: FoodItem] = [:]
        for i in 1...5 {
            let food = FoodItem(
                context: context,
                id: UUID(),
                name: "Batch Food \(i)",
                brand: "Batch Brand",
                servingSize: 100,
                carbs: Double(i * 2),
                netCarbs: Double(i),
                fat: 5.0,
                protein: 3.0,
                kcal: 100.0
            )
            batchItems[String(format: "%012d", i)] = food
        }

        await cache.batchUpdate(batchItems)
        print("   ✓ Batch updated \(batchItems.count) items")

        // Verify batch items
        let batchLookup = await cache.lookup("000000000003")
        if let item = batchLookup {
            print("   ✓ Batch item verified: \(item.name)")
        }

        // Test 7: Final statistics
        print("\n7. Final cache statistics:")
        let finalStats = await cache.getStats()
        print("   Total entries: \(finalStats.totalEntries)")
        print("   Cache file size: \(finalStats.cacheFileSize) bytes")

        print("\n=== Verification Complete ===\n")
    }
}
