import Foundation

// MARK: - Retry Item Model

/// Represents a UPC barcode that failed lookup and needs retry
struct RetryItem: Codable, Equatable, Identifiable {
    let id: UUID
    let upc: String
    var attempts: Int
    let firstAttempt: Date
    var lastAttempt: Date
    var nextRetryTime: Date

    init(upc: String, firstAttempt: Date = Date()) {
        self.id = UUID()
        self.upc = upc
        self.attempts = 0
        self.firstAttempt = firstAttempt
        self.lastAttempt = firstAttempt
        self.nextRetryTime = firstAttempt
    }

    /// Calculate next retry time based on attempt number
    /// Exponential backoff: 30s, 2min, 10min
    static func calculateNextRetryTime(from lastAttempt: Date, attempts: Int) -> Date {
        let backoffIntervals: [TimeInterval] = [
            30,        // 30 seconds (first retry)
            120,       // 2 minutes (second retry)
            600        // 10 minutes (third retry)
        ]

        let interval = attempts < backoffIntervals.count
            ? backoffIntervals[attempts]
            : backoffIntervals.last ?? 600

        return lastAttempt.addingTimeInterval(interval)
    }

    /// Update retry metadata after a failed attempt
    mutating func recordFailedAttempt() {
        attempts += 1
        lastAttempt = Date()
        nextRetryTime = Self.calculateNextRetryTime(from: lastAttempt, attempts: attempts)
    }

    /// Check if item has exceeded max retry attempts
    var hasExceededMaxAttempts: Bool {
        return attempts >= 3
    }

    /// Check if item is ready for retry
    func isReadyForRetry(at currentTime: Date = Date()) -> Bool {
        return currentTime >= nextRetryTime && !hasExceededMaxAttempts
    }
}

// MARK: - Retry Queue Statistics

struct RetryQueueStats {
    let totalItems: Int
    let readyForRetry: Int
    let pendingRetry: Int
    let maxAttemptsReached: Int
    let queueFileSize: Int64
}

// MARK: - UPC Retry Queue

/// Thread-safe actor for managing failed UPC lookup retry queue
/// Stores queue in Documents/cf_upc_retry_queue.json with exponential backoff
actor UPCRetryQueue {

    // MARK: - Constants

    private static let maxRetryAttempts = 3
    private static let maxBatchSize = 20
    private static let queueFileName = "cf_upc_retry_queue.json"

    // MARK: - Properties

    /// In-memory queue: sorted by nextRetryTime
    private var queue: [RetryItem] = []

    /// File path for persistent storage
    private let queueFilePath: URL

    /// Flag to check if feature is enabled
    private let isEnabled: Bool

    // MARK: - Initialization

    init() {
        // Read feature flag directly from UserDefaults (nonisolated)
        self.isEnabled = UserDefaults.standard.bool(forKey: "cf_scancache")

        // Determine queue file location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.queueFilePath = documentsPath.appendingPathComponent(Self.queueFileName)

        // Load existing queue from disk
        Task {
            await loadQueue()
        }
    }

    // MARK: - Public Methods

    /// Add a failed UPC lookup to the retry queue
    /// - Parameter upc: The barcode that failed lookup
    func addFailedLookup(upc: String) async {
        guard isEnabled else { return }

        // Check if UPC already in queue
        if let existingIndex = queue.firstIndex(where: { $0.upc == upc }) {
            var existingItem = queue[existingIndex]

            // If max attempts reached, remove from queue
            if existingItem.hasExceededMaxAttempts {
                queue.remove(at: existingIndex)
                await saveQueue()
                return
            }

            // Record failed attempt and update
            existingItem.recordFailedAttempt()
            queue[existingIndex] = existingItem
        } else {
            // Add new item to queue
            let newItem = RetryItem(upc: upc)
            queue.append(newItem)
        }

        // Sort queue by nextRetryTime
        sortQueue()

        // Persist to disk
        await saveQueue()
    }

    /// Mark a UPC lookup as successful and remove from queue
    /// - Parameter upc: The barcode that was successfully looked up
    func markSuccessful(upc: String) async {
        guard isEnabled else { return }

        queue.removeAll { $0.upc == upc }
        await saveQueue()
    }

    /// Get next batch of items ready for retry
    /// - Parameter maxItems: Maximum number of items to return (default: 20)
    /// - Returns: Array of UPC strings ready for retry, sorted by priority
    func getReadyForRetry(maxItems: Int = maxBatchSize) async -> [String] {
        guard isEnabled else { return [] }

        let currentTime = Date()

        // Filter items ready for retry
        let readyItems = queue
            .filter { $0.isReadyForRetry(at: currentTime) }
            .prefix(maxItems)
            .map { $0.upc }

        return Array(readyItems)
    }

    /// Get specific retry item details
    /// - Parameter upc: The barcode to look up
    /// - Returns: RetryItem if found in queue
    func getItem(for upc: String) async -> RetryItem? {
        guard isEnabled else { return nil }
        return queue.first { $0.upc == upc }
    }

    /// Remove specific UPC from queue
    /// - Parameter upc: The barcode to remove
    func remove(upc: String) async {
        guard isEnabled else { return }

        queue.removeAll { $0.upc == upc }
        await saveQueue()
    }

    /// Clear all items from queue
    func clear() async {
        queue.removeAll()
        await saveQueue()
    }

    /// Clean up expired items (exceeded max attempts)
    func cleanupExpiredItems() async {
        guard isEnabled else { return }

        let beforeCount = queue.count
        queue.removeAll { $0.hasExceededMaxAttempts }

        if queue.count != beforeCount {
            await saveQueue()
        }
    }

    /// Get queue statistics
    /// - Returns: Current queue statistics
    func getStats() async -> RetryQueueStats {
        let currentTime = Date()

        let readyCount = queue.filter { $0.isReadyForRetry(at: currentTime) }.count
        let pendingCount = queue.filter { !$0.isReadyForRetry(at: currentTime) && !$0.hasExceededMaxAttempts }.count
        let maxAttemptsCount = queue.filter { $0.hasExceededMaxAttempts }.count

        var fileSize: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: queueFilePath.path) {
            fileSize = attributes[.size] as? Int64 ?? 0
        }

        return RetryQueueStats(
            totalItems: queue.count,
            readyForRetry: readyCount,
            pendingRetry: pendingCount,
            maxAttemptsReached: maxAttemptsCount,
            queueFileSize: fileSize
        )
    }

    /// Check if queue contains a specific UPC
    /// - Parameter upc: The barcode to check
    /// - Returns: True if UPC exists in queue
    func contains(upc: String) async -> Bool {
        return queue.contains { $0.upc == upc }
    }

    /// Get all items in queue (for debugging/testing)
    /// - Returns: Array of all retry items
    func getAllItems() async -> [RetryItem] {
        return queue
    }

    // MARK: - Private Methods

    /// Sort queue by nextRetryTime (ascending)
    private func sortQueue() {
        queue.sort { $0.nextRetryTime < $1.nextRetryTime }
    }

    /// Load queue from disk
    private func loadQueue() {
        guard FileManager.default.fileExists(atPath: queueFilePath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: queueFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            queue = try decoder.decode([RetryItem].self, from: data)

            // Sort queue by nextRetryTime
            sortQueue()

        } catch {
            // If queue file is corrupted, start fresh
            print("Failed to load retry queue: \(error)")
            queue = []
        }
    }

    /// Save queue to disk
    private func saveQueue() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(queue)
            try data.write(to: queueFilePath, options: [.atomic])

        } catch {
            // Log error but don't crash - queue will be rebuilt on next launch
            print("Failed to save retry queue: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

extension UPCRetryQueue {

    /// Shared singleton instance
    static let shared = UPCRetryQueue()

    /// Get queue file path (useful for debugging)
    nonisolated var queueFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(Self.queueFileName)
    }
}

// MARK: - Retry Item Extensions

extension RetryItem {

    /// Human-readable description of retry status
    var retryStatusDescription: String {
        if hasExceededMaxAttempts {
            return "Max attempts reached"
        }

        let now = Date()
        if isReadyForRetry(at: now) {
            return "Ready for retry"
        }

        let timeUntilRetry = nextRetryTime.timeIntervalSince(now)
        if timeUntilRetry < 60 {
            return "Retry in \(Int(timeUntilRetry))s"
        } else if timeUntilRetry < 3600 {
            return "Retry in \(Int(timeUntilRetry / 60))m"
        } else {
            return "Retry in \(Int(timeUntilRetry / 3600))h"
        }
    }

    /// Time interval until next retry
    func timeUntilNextRetry(from currentTime: Date = Date()) -> TimeInterval {
        let interval = nextRetryTime.timeIntervalSince(currentTime)
        return max(0, interval)
    }
}
