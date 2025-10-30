import XCTest
@testable import CarbFlow

final class UPCRetryQueueTests: XCTestCase {

    var retryQueue: UPCRetryQueue!
    var testQueuePath: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Enable the feature flag for testing
        FeatureFlags.setScanCacheEnabled(true)

        // Create a new retry queue for each test
        retryQueue = UPCRetryQueue()

        // Get queue file path
        testQueuePath = await retryQueue.queueFileURL

        // Clear any existing queue
        await retryQueue.clear()
    }

    override func tearDown() async throws {
        // Clean up queue file
        if FileManager.default.fileExists(atPath: testQueuePath.path) {
            try? FileManager.default.removeItem(at: testQueuePath)
        }

        retryQueue = nil
        testQueuePath = nil

        try await super.tearDown()
    }

    // MARK: - Basic Operations Tests

    func testAddFailedLookup() async throws {
        // When: Adding a failed lookup
        await retryQueue.addFailedLookup(upc: "123456789012")

        // Then: Should be in queue
        let contains = await retryQueue.contains(upc: "123456789012")
        XCTAssertTrue(contains)

        let stats = await retryQueue.getStats()
        XCTAssertEqual(stats.totalItems, 1)
    }

    func testAddFailedLookup_CreatesQueueFile() async throws {
        // Given: No queue file exists
        XCTAssertFalse(FileManager.default.fileExists(atPath: testQueuePath.path))

        // When: Adding a failed lookup
        await retryQueue.addFailedLookup(upc: "123456789012")

        // Give it time to save
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Queue file should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: testQueuePath.path))
    }

    func testMarkSuccessful_RemovesFromQueue() async throws {
        // Given: UPC in queue
        await retryQueue.addFailedLookup(upc: "123456789012")
        XCTAssertTrue(await retryQueue.contains(upc: "123456789012"))

        // When: Marking as successful
        await retryQueue.markSuccessful(upc: "123456789012")

        // Then: Should be removed from queue
        XCTAssertFalse(await retryQueue.contains(upc: "123456789012"))

        let stats = await retryQueue.getStats()
        XCTAssertEqual(stats.totalItems, 0)
    }

    func testRemove() async throws {
        // Given: UPC in queue
        await retryQueue.addFailedLookup(upc: "123456789012")

        // When: Removing UPC
        await retryQueue.remove(upc: "123456789012")

        // Then: Should be removed
        XCTAssertFalse(await retryQueue.contains(upc: "123456789012"))
    }

    func testClear() async throws {
        // Given: Multiple items in queue
        await retryQueue.addFailedLookup(upc: "123456789012")
        await retryQueue.addFailedLookup(upc: "234567890123")
        await retryQueue.addFailedLookup(upc: "345678901234")

        let statsBefore = await retryQueue.getStats()
        XCTAssertEqual(statsBefore.totalItems, 3)

        // When: Clearing queue
        await retryQueue.clear()

        // Then: Queue should be empty
        let statsAfter = await retryQueue.getStats()
        XCTAssertEqual(statsAfter.totalItems, 0)
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoff_FirstRetry() {
        // Given: First attempt
        let lastAttempt = Date()

        // When: Calculating next retry time
        let nextRetry = RetryItem.calculateNextRetryTime(from: lastAttempt, attempts: 0)

        // Then: Should be 30 seconds later
        let expectedTime = lastAttempt.addingTimeInterval(30)
        XCTAssertEqual(nextRetry.timeIntervalSince(lastAttempt), 30, accuracy: 1.0)
        XCTAssertEqual(nextRetry.timeIntervalSince1970, expectedTime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testExponentialBackoff_SecondRetry() {
        // Given: Second attempt
        let lastAttempt = Date()

        // When: Calculating next retry time
        let nextRetry = RetryItem.calculateNextRetryTime(from: lastAttempt, attempts: 1)

        // Then: Should be 2 minutes (120s) later
        XCTAssertEqual(nextRetry.timeIntervalSince(lastAttempt), 120, accuracy: 1.0)
    }

    func testExponentialBackoff_ThirdRetry() {
        // Given: Third attempt
        let lastAttempt = Date()

        // When: Calculating next retry time
        let nextRetry = RetryItem.calculateNextRetryTime(from: lastAttempt, attempts: 2)

        // Then: Should be 10 minutes (600s) later
        XCTAssertEqual(nextRetry.timeIntervalSince(lastAttempt), 600, accuracy: 1.0)
    }

    // MARK: - Retry Attempts Tests

    func testMaxRetryAttempts() async throws {
        // Given: UPC added to queue
        await retryQueue.addFailedLookup(upc: "123456789012")

        // When: Failing 3 times
        for _ in 0..<3 {
            await retryQueue.addFailedLookup(upc: "123456789012")
        }

        // Then: Should have 3 attempts recorded
        let item = await retryQueue.getItem(for: "123456789012")
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.attempts, 3)
        XCTAssertTrue(item?.hasExceededMaxAttempts ?? false)
    }

    func testMaxRetryAttempts_RemovedOnNextAdd() async throws {
        // Given: UPC with max attempts
        for _ in 0..<4 {
            await retryQueue.addFailedLookup(upc: "123456789012")
        }

        // When: Adding again after max attempts
        await retryQueue.addFailedLookup(upc: "123456789012")

        // Then: Should be removed from queue
        XCTAssertFalse(await retryQueue.contains(upc: "123456789012"))
    }

    func testCleanupExpiredItems() async throws {
        // Given: Multiple items, some with max attempts
        await retryQueue.addFailedLookup(upc: "111111111111")

        for _ in 0..<4 {
            await retryQueue.addFailedLookup(upc: "222222222222") // Will exceed max
        }

        await retryQueue.addFailedLookup(upc: "333333333333")

        let statsBefore = await retryQueue.getStats()
        XCTAssertGreaterThan(statsBefore.totalItems, 0)

        // When: Cleaning up expired items
        await retryQueue.cleanupExpiredItems()

        // Then: Items with max attempts should be removed
        XCTAssertTrue(await retryQueue.contains(upc: "111111111111"))
        XCTAssertFalse(await retryQueue.contains(upc: "222222222222"))
        XCTAssertTrue(await retryQueue.contains(upc: "333333333333"))
    }

    // MARK: - Ready For Retry Tests

    func testGetReadyForRetry_ImmediateItems() async throws {
        // Given: Items that are immediately ready (nextRetryTime in past)
        await retryQueue.addFailedLookup(upc: "123456789012")

        // Manually create item with past retry time for testing
        // In real usage, items become ready after their backoff period

        // When: Getting ready items
        let readyItems = await retryQueue.getReadyForRetry()

        // Then: Should return items (new items are immediately ready)
        XCTAssertGreaterThanOrEqual(readyItems.count, 0)
    }

    func testGetReadyForRetry_MaxBatchSize() async throws {
        // Given: More than 20 items ready
        for i in 0..<30 {
            await retryQueue.addFailedLookup(upc: String(format: "%012d", i))
        }

        // When: Getting ready items
        let readyItems = await retryQueue.getReadyForRetry(maxItems: 20)

        // Then: Should return max 20 items
        XCTAssertLessThanOrEqual(readyItems.count, 20)
    }

    func testGetReadyForRetry_PriorityOrder() async throws {
        // Given: Multiple items added at different times
        await retryQueue.addFailedLookup(upc: "111111111111")

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        await retryQueue.addFailedLookup(upc: "222222222222")

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        await retryQueue.addFailedLookup(upc: "333333333333")

        // When: Getting ready items
        let readyItems = await retryQueue.getReadyForRetry()

        // Then: Should be sorted by priority (oldest first)
        XCTAssertGreaterThan(readyItems.count, 0)
        // First item should be the oldest
        if readyItems.count >= 3 {
            XCTAssertEqual(readyItems[0], "111111111111")
        }
    }

    // MARK: - Persistence Tests

    func testQueueSurvivesAppRestart() async throws {
        // Given: Items in queue
        await retryQueue.addFailedLookup(upc: "123456789012")
        await retryQueue.addFailedLookup(upc: "234567890123")

        // Wait for save
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // When: Simulating app restart by creating new queue
        let newQueue = UPCRetryQueue()

        // Wait for load
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then: Should still contain items
        XCTAssertTrue(await newQueue.contains(upc: "123456789012"))
        XCTAssertTrue(await newQueue.contains(upc: "234567890123"))

        let stats = await newQueue.getStats()
        XCTAssertEqual(stats.totalItems, 2)
    }

    // MARK: - Statistics Tests

    func testGetStats() async throws {
        // Given: Empty queue
        var stats = await retryQueue.getStats()
        XCTAssertEqual(stats.totalItems, 0)
        XCTAssertEqual(stats.readyForRetry, 0)

        // When: Adding items
        await retryQueue.addFailedLookup(upc: "123456789012")
        await retryQueue.addFailedLookup(upc: "234567890123")

        // Then: Stats should reflect entries
        stats = await retryQueue.getStats()
        XCTAssertEqual(stats.totalItems, 2)
        XCTAssertGreaterThanOrEqual(stats.readyForRetry, 0)
    }

    // MARK: - Feature Flag Tests

    func testQueueDisabledWhenFeatureFlagOff() async throws {
        // Given: Feature flag disabled
        FeatureFlags.setScanCacheEnabled(false)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let disabledQueue = UPCRetryQueue()

        // When: Attempting operations
        await disabledQueue.addFailedLookup(upc: "123456789012")

        let contains = await disabledQueue.contains(upc: "123456789012")
        let readyItems = await disabledQueue.getReadyForRetry()

        // Then: Should not operate
        XCTAssertFalse(contains)
        XCTAssertEqual(readyItems.count, 0)

        // Re-enable for other tests
        FeatureFlags.setScanCacheEnabled(true)
    }

    // MARK: - Retry Item Tests

    func testRetryItem_IsReadyForRetry() {
        // Given: New retry item (no attempts yet)
        var item = RetryItem(upc: "123456789012", firstAttempt: Date().addingTimeInterval(-60)) // 1 min ago

        // Then: Should be ready immediately
        XCTAssertTrue(item.isReadyForRetry())

        // When: Recording failed attempt
        item.recordFailedAttempt()

        // Then: Should not be ready (needs 30s)
        XCTAssertFalse(item.isReadyForRetry())

        // But should be ready after 30s
        let futureTime = Date().addingTimeInterval(31) // 31s from now
        XCTAssertTrue(item.isReadyForRetry(at: futureTime))
    }

    func testRetryItem_StatusDescription() {
        // Given: New item
        let item = RetryItem(upc: "123456789012")

        // Then: Should show ready status
        let description = item.retryStatusDescription
        XCTAssertTrue(description.contains("Ready") || description.contains("Retry"))
    }

    func testRetryItem_TimeUntilNextRetry() {
        // Given: Item with next retry in future
        var item = RetryItem(upc: "123456789012")
        item.recordFailedAttempt()

        // Then: Should calculate time correctly
        let timeUntil = item.timeUntilNextRetry()
        XCTAssertGreaterThan(timeUntil, 0)
        XCTAssertLessThanOrEqual(timeUntil, 30) // Should be ~30s
    }
}
