# UPC Cache Store

## Overview

`UPCCacheStore` is a thread-safe, actor-based caching system for storing barcode-to-food mappings locally on the device. It provides fast lookup times (<50ms) and efficient LRU (Least Recently Used) eviction for managing cache size.

## Features

- **Thread-Safe**: Uses Swift actor for safe concurrent access
- **Fast Lookups**: Returns results in <50ms for cached items
- **LRU Eviction**: Automatically removes oldest entries when cache exceeds 10,000 items
- **JSON Persistence**: Stores cache to `Documents/cf_upc_cache.json`
- **Batch Operations**: Supports batch updates for background sync
- **Export/Import**: Backup and restore cache data
- **Feature Flag**: Controlled by `cf_scancache` flag

## Usage

### Basic Operations

```swift
// Get shared instance
let cache = UPCCacheStore.shared

// Store a UPC mapping
await cache.store(upc: "042343370210", foodItem: almondButter)

// Lookup a cached item
if let cachedItem = await cache.lookup("042343370210") {
    // Convert to FoodItem for display
    let foodItem = await cachedItem.toFoodItem(context: viewContext)
    // Use foodItem...
}

// Check if UPC exists in cache
let exists = await cache.contains(upc: "042343370210")

// Remove a specific UPC
await cache.remove(upc: "042343370210")

// Clear entire cache
await cache.clear()
```

### Batch Operations

```swift
// Batch update for background sync
let mappings: [String: FoodItem] = [
    "123456789012": food1,
    "234567890123": food2,
    "345678901234": food3
]

await cache.batchUpdate(mappings)
```

### Export/Import

```swift
// Export cache for backup
let exportData = try await cache.exportCache()
try exportData.write(to: backupURL)

// Import cache from backup
let importData = try Data(contentsOf: backupURL)
try await cache.importCache(from: importData)
```

### Cache Statistics

```swift
let stats = await cache.getStats()
print("Total entries: \(stats.totalEntries)")
print("Cache file size: \(stats.cacheFileSize) bytes")
print("Oldest entry: \(stats.oldestEntry)")
print("Newest entry: \(stats.newestEntry)")
```

## Data Structure

### CachedUPCItem

Stores all relevant food information for cache:

```swift
struct CachedUPCItem: Codable {
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
}
```

### Converting to FoodItem

To display a cached item in the UI:

```swift
let cachedItem = await cache.lookup(upc)
let foodItem = await cachedItem?.toFoodItem(context: viewContext)
```

## Cache Location

- **Path**: `Documents/cf_upc_cache.json`
- **Format**: JSON (pretty-printed, sorted keys)
- **Size Limit**: 10,000 entries maximum
- **Persistence**: Survives app restarts

## LRU Eviction

When the cache reaches 10,000 entries:
1. Oldest (least recently accessed) entries are evicted first
2. Access to an item updates its position in the LRU queue
3. Eviction happens automatically during `store()` and `batchUpdate()`

## Feature Flag

The cache is controlled by the `cf_scancache` feature flag:

```swift
// Enable cache
FeatureFlags.setScanCacheEnabled(true)

// Disable cache
FeatureFlags.setScanCacheEnabled(false)
```

When disabled:
- All operations return immediately without side effects
- Lookups return `nil`
- Storage operations are ignored

## Performance

- **Lookup Time**: <50ms (typically <10ms for in-memory hits)
- **Storage Time**: <100ms including disk write
- **Batch Updates**: ~1-2ms per item
- **Memory Usage**: ~500 bytes per cached item

## Testing

### Manual Verification

Use the verification helper for quick testing:

```swift
await UPCCacheStore.verify(context: viewContext)
```

This will:
1. Check cache file location
2. Store and retrieve test items
3. Measure lookup performance
4. Verify persistence
5. Test batch operations
6. Display cache statistics

### Unit Tests

See `CarbFlowTests/UPCCacheStoreTests.swift` for comprehensive test coverage:
- Basic functionality (store, lookup, remove)
- Performance benchmarks
- LRU eviction
- Batch operations
- Export/import
- Thread safety
- Feature flag behavior
- Cache persistence

## Integration

### Scanner Workflow

1. User scans barcode
2. Check cache for UPC: `await cache.lookup(upc)`
3. If hit: Display cached food item immediately
4. If miss: Fetch from API, then store: `await cache.store(upc: upc, foodItem: foodItem)`

### Background Sync

For syncing large datasets:

```swift
let mappings = fetchUPCMappingsFromServer()
await cache.batchUpdate(mappings)
```

## Troubleshooting

### Cache Not Working

1. Check feature flag: `FeatureFlags.cf_scancache`
2. Verify file permissions for Documents directory
3. Check disk space
4. Review console for error messages

### Performance Issues

1. Monitor cache size: `await cache.getStats()`
2. Consider clearing cache: `await cache.clear()`
3. Check for disk I/O bottlenecks
4. Verify LRU eviction is working

### Data Corruption

If cache file becomes corrupted:
- Cache automatically starts fresh on next launch
- Old corrupted file is ignored
- No user data loss (cache is just an optimization)

## Future Enhancements

Potential improvements:
- SQLite backend for larger caches
- Cache warming strategies
- Network sync integration
- Analytics on hit/miss rates
- Compression for larger datasets
- TTL (Time To Live) for entries
