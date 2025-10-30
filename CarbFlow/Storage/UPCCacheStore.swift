import Foundation
import CoreData

// MARK: - Cached UPC Item Model

/// Represents a cached barcode-to-food mapping
struct CachedUPCItem: Codable, Equatable {
    let upc: String
    let foodId: UUID
    let name: String
    let netCarbs: Double
    let carbs: Double
    let fat: Double
    let protein: Double
    let kcal: Double
    let servingSize: Double?
    let brand: String?
    var lastUpdated: Date

    init(upc: String, foodItem: FoodItem) {
        self.upc = upc
        self.foodId = foodItem.id
        self.name = foodItem.name
        self.netCarbs = foodItem.netCarbs
        self.carbs = foodItem.carbs
        self.fat = foodItem.fat
        self.protein = foodItem.protein
        self.kcal = foodItem.kcal
        self.servingSize = foodItem.servingSize
        self.brand = foodItem.brand
        self.lastUpdated = Date()
    }

    /// Create a temporary FoodItem from cached data (requires Core Data context)
    @MainActor
    func toFoodItem(context: NSManagedObjectContext) -> FoodItem {
        return FoodItem(
            context: context,
            id: foodId,
            name: name,
            brand: brand,
            servingSize: servingSize,
            carbs: carbs,
            netCarbs: netCarbs,
            fat: fat,
            protein: protein,
            kcal: kcal,
            upc: upc,
            isVerified: false,
            internalReviewNote: nil,
            isUserCreated: false,
            createdAt: lastUpdated,
            updatedAt: lastUpdated
        )
    }
}

// MARK: - Cache Statistics

struct UPCCacheStats {
    let totalEntries: Int
    let oldestEntry: Date?
    let newestEntry: Date?
    let cacheFileSize: Int64
}

// MARK: - UPC Cache Store

/// Thread-safe actor for managing local barcode-to-food mappings
/// Stores mappings in Documents/cf_upc_cache.json with LRU eviction
actor UPCCacheStore {

    // MARK: - Constants

    private static let maxEntries = 10_000
    private static let cacheFileName = "cf_upc_cache.json"

    // MARK: - Properties

    /// In-memory cache: UPC -> CachedUPCItem
    private var cache: [String: CachedUPCItem] = [:]

    /// LRU tracking: maintains access order
    private var lruQueue: [String] = []

    /// File path for persistent storage
    private let cacheFilePath: URL

    /// Flag to check if feature is enabled
    private let isEnabled: Bool

    // MARK: - Initialization

    init() {
        // Read feature flag directly from UserDefaults (nonisolated)
        self.isEnabled = UserDefaults.standard.bool(forKey: "cf_scancache")

        // Determine cache file location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheFilePath = documentsPath.appendingPathComponent(Self.cacheFileName)

        // Load existing cache from disk
        Task {
            await loadCache()
        }
    }

    // MARK: - Public Methods

    /// Look up a cached food item by UPC barcode
    /// - Parameters:
    ///   - upc: The barcode string
    ///   - context: Core Data context to create the FoodItem in
    /// - Returns: Optional CachedUPCItem if found in cache
    func lookup(_ upc: String) async -> CachedUPCItem? {
        guard isEnabled else { return nil }

        guard let cachedItem = cache[upc] else {
            return nil
        }

        // Update LRU: move to end (most recently used)
        updateLRU(upc: upc)

        // Update lastUpdated timestamp
        cache[upc]?.lastUpdated = Date()

        return cachedItem
    }

    /// Store a single UPC mapping
    /// - Parameters:
    ///   - upc: The barcode string
    ///   - foodItem: The associated food item
    func store(upc: String, foodItem: FoodItem) async {
        guard isEnabled else { return }

        let cachedItem = CachedUPCItem(upc: upc, foodItem: foodItem)

        cache[upc] = cachedItem
        updateLRU(upc: upc)

        // Enforce size limit
        await evictIfNeeded()

        // Persist to disk
        await saveCache()
    }

    /// Batch update multiple UPC mappings (for background sync)
    /// - Parameter mappings: Dictionary of UPC -> FoodItem
    func batchUpdate(_ mappings: [String: FoodItem]) async {
        guard isEnabled else { return }

        for (upc, foodItem) in mappings {
            let cachedItem = CachedUPCItem(upc: upc, foodItem: foodItem)

            cache[upc] = cachedItem
            updateLRU(upc: upc)
        }

        // Enforce size limit
        await evictIfNeeded()

        // Persist to disk
        await saveCache()
    }

    /// Remove a specific UPC from cache
    /// - Parameter upc: The barcode string to remove
    func remove(upc: String) async {
        cache.removeValue(forKey: upc)
        lruQueue.removeAll { $0 == upc }
        await saveCache()
    }

    /// Clear all cached entries
    func clear() async {
        cache.removeAll()
        lruQueue.removeAll()
        await saveCache()
    }

    /// Export cache data for backup
    /// - Returns: JSON data representation of cache
    func exportCache() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(cache)
    }

    /// Import cache data from backup
    /// - Parameter data: JSON data containing cache mappings
    func importCache(from data: Data) async throws {
        guard isEnabled else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedCache = try decoder.decode([String: CachedUPCItem].self, from: data)

        // Merge with existing cache (imported items take precedence)
        for (upc, item) in importedCache {
            cache[upc] = item
            updateLRU(upc: upc)
        }

        // Enforce size limit
        await evictIfNeeded()

        // Persist to disk
        await saveCache()
    }

    /// Get cache statistics
    /// - Returns: Current cache statistics
    func getStats() async -> UPCCacheStats {
        let dates = cache.values.map { $0.lastUpdated }
        let oldestEntry = dates.min()
        let newestEntry = dates.max()

        var fileSize: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: cacheFilePath.path) {
            fileSize = attributes[.size] as? Int64 ?? 0
        }

        return UPCCacheStats(
            totalEntries: cache.count,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry,
            cacheFileSize: fileSize
        )
    }

    /// Check if cache contains a UPC
    /// - Parameter upc: The barcode string
    /// - Returns: True if UPC exists in cache
    func contains(upc: String) async -> Bool {
        return cache[upc] != nil
    }

    // MARK: - Private Methods

    /// Update LRU queue: move UPC to end (most recently used)
    private func updateLRU(upc: String) {
        // Remove existing entry
        lruQueue.removeAll { $0 == upc }
        // Add to end (most recent)
        lruQueue.append(upc)
    }

    /// Evict oldest entries if cache exceeds max size
    private func evictIfNeeded() async {
        while cache.count > Self.maxEntries {
            // Remove least recently used (first in queue)
            guard let oldestUPC = lruQueue.first else { break }

            cache.removeValue(forKey: oldestUPC)
            lruQueue.removeFirst()
        }
    }

    /// Load cache from disk
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFilePath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: cacheFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            cache = try decoder.decode([String: CachedUPCItem].self, from: data)

            // Rebuild LRU queue sorted by lastUpdated (oldest to newest)
            lruQueue = cache
                .sorted { $0.value.lastUpdated < $1.value.lastUpdated }
                .map { $0.key }

        } catch {
            // If cache file is corrupted, start fresh
            cache = [:]
            lruQueue = []
        }
    }

    /// Save cache to disk
    private func saveCache() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(cache)
            try data.write(to: cacheFilePath, options: [.atomic])

        } catch {
            // Log error but don't crash - cache will be rebuilt on next launch
            print("Failed to save UPC cache: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

extension UPCCacheStore {

    /// Shared singleton instance
    static let shared = UPCCacheStore()

    /// Get cache file path (useful for debugging)
    nonisolated var cacheFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(Self.cacheFileName)
    }
}
