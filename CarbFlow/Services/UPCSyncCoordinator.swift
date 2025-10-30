import Foundation
import Combine
import CoreData

// MARK: - Sync Progress

struct SyncProgress: Equatable {
    let current: Int
    let total: Int
    let successful: Int
    let failed: Int

    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var isComplete: Bool {
        return current >= total
    }
}

// MARK: - Sync Result

struct SyncResult: Equatable {
    let successful: [String]  // UPCs that were found
    let failed: [String]      // UPCs that weren't found
    let errors: [String]      // UPCs that had errors
}

// MARK: - UPC Sync Coordinator

/// Coordinates background syncing of retry queue when network is available
@MainActor
final class UPCSyncCoordinator: ObservableObject {

    // MARK: - Published Properties

    /// Whether sync is currently in progress
    @Published private(set) var isSyncing: Bool = false

    /// Current sync progress
    @Published private(set) var syncProgress: SyncProgress?

    /// Last sync result
    @Published private(set) var lastSyncResult: SyncResult?

    /// Last sync timestamp
    @Published private(set) var lastSyncTime: Date?

    // MARK: - Private Properties

    private let networkMonitor: NetworkMonitor
    private let retryQueue = UPCRetryQueue.shared
    private let cacheStore = UPCCacheStore.shared

    private var cancellables = Set<AnyCancellable>()

    /// Rate limiting: minimum time between syncs
    private let rateLimitInterval: TimeInterval = 10.0
    private var lastSyncAttempt: Date?

    /// Mock API configuration
    private let apiTimeout: TimeInterval = 10.0
    private let successRate: Double = 0.7  // 70% success rate for mock

    /// Feature flag
    private let isEnabled: Bool

    // MARK: - Initialization

    init(networkMonitor: NetworkMonitor) {
        self.networkMonitor = networkMonitor
        self.isEnabled = FeatureFlags.cf_scancache

        setupNetworkObserver()
    }

    convenience init() {
        self.init(networkMonitor: NetworkMonitor.shared)
    }

    // MARK: - Public Methods

    /// Manually trigger sync (respects rate limiting)
    func triggerSync() async {
        guard isEnabled else { return }
        guard !isSyncing else { return }
        guard canSync() else { return }

        await performSync()
    }

    /// Force sync immediately (ignores rate limiting, for user-initiated actions)
    func forceSyncNow() async {
        guard isEnabled else { return }
        guard !isSyncing else { return }

        await performSync()
    }

    // MARK: - Private Methods

    private func setupNetworkObserver() {
        guard isEnabled else { return }

        // Observe network reconnection
        networkMonitor.$didReconnect
            .filter { $0 } // Only when reconnected
            .sink { [weak self] _ in
                Task { @MainActor in
                    // Wait 5s after reconnection before syncing
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    await self?.triggerSync()
                }
            }
            .store(in: &cancellables)
    }

    private func canSync() -> Bool {
        // Check network connectivity
        guard networkMonitor.isConnected else {
            return false
        }

        // Check rate limiting
        if let lastAttempt = lastSyncAttempt {
            let timeSinceLastSync = Date().timeIntervalSince(lastAttempt)
            return timeSinceLastSync >= rateLimitInterval
        }

        return true
    }

    private func performSync() async {
        isSyncing = true
        lastSyncAttempt = Date()

        // Get items ready for retry (max 20)
        let upcsToRetry = await retryQueue.getReadyForRetry(maxItems: 20)

        guard !upcsToRetry.isEmpty else {
            isSyncing = false
            return
        }

        // Initialize progress
        syncProgress = SyncProgress(
            current: 0,
            total: upcsToRetry.count,
            successful: 0,
            failed: 0
        )

        // Process batch
        let result = await processBatch(upcs: upcsToRetry)

        // Update last sync result
        lastSyncResult = result
        lastSyncTime = Date()

        // Mark progress as complete
        syncProgress = SyncProgress(
            current: upcsToRetry.count,
            total: upcsToRetry.count,
            successful: result.successful.count,
            failed: result.failed.count
        )

        isSyncing = false

        // Clear progress after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.syncProgress = nil
        }
    }

    private func processBatch(upcs: [String]) async -> SyncResult {
        var successful: [String] = []
        var failed: [String] = []
        var errors: [String] = []

        for (index, upc) in upcs.enumerated() {
            // Fetch from mock API
            let fetchResult = await fetchFromAPI(upc: upc)

            switch fetchResult {
            case .success(let foodItem):
                // Cache successful result
                await cacheStore.store(upc: upc, foodItem: foodItem)

                // Remove from retry queue
                await retryQueue.markSuccessful(upc: upc)

                successful.append(upc)

            case .notFound:
                // Add back to retry queue (increments attempts)
                await retryQueue.addFailedLookup(upc: upc)

                failed.append(upc)

            case .error:
                // Add back to retry queue
                await retryQueue.addFailedLookup(upc: upc)

                errors.append(upc)
            }

            // Update progress
            let currentProgress = index + 1
            syncProgress = SyncProgress(
                current: currentProgress,
                total: upcs.count,
                successful: successful.count,
                failed: failed.count
            )

            // Small delay between requests to avoid overwhelming API
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return SyncResult(
            successful: successful,
            failed: failed,
            errors: errors
        )
    }

    // MARK: - Mock API

    private enum APIResult {
        case success(FoodItem)
        case notFound
        case error
    }

    private func fetchFromAPI(upc: String) async -> APIResult {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: UInt64.random(in: 200_000_000...500_000_000)) // 200-500ms

        // Mock timeout
        let shouldTimeout = Double.random(in: 0...1) > 0.95 // 5% chance of timeout
        if shouldTimeout {
            return .error
        }

        // Mock success/not found based on success rate
        let shouldSucceed = Double.random(in: 0...1) < successRate

        if shouldSucceed {
            // Create mock food item
            // Note: In production, this would parse API response
            let mockFoodItem = await createMockFoodItem(upc: upc)
            return .success(mockFoodItem)
        } else {
            return .notFound
        }
    }

    @MainActor
    private func createMockFoodItem(upc: String) async -> FoodItem {
        // Get or create in-memory context for mock data
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = nil // In-memory only

        let mockNames = [
            "Almond Butter",
            "Greek Yogurt",
            "Protein Bar",
            "Cheese Stick",
            "Mixed Nuts",
            "Dark Chocolate",
            "Avocado",
            "Eggs",
        ]

        let mockBrands = [
            "Justin's",
            "Fage",
            "Quest",
            "Sargento",
            "Blue Diamond",
            "Lily's",
            "Organic",
            "Happy Egg",
        ]

        let randomName = mockNames.randomElement() ?? "Product"
        let randomBrand = mockBrands.randomElement()
        let randomNetCarbs = Double.random(in: 2...15)
        let randomCarbs = randomNetCarbs + Double.random(in: 1...5)

        return FoodItem(
            context: context,
            id: UUID(),
            name: randomName,
            brand: randomBrand,
            servingSize: 100,
            carbs: randomCarbs,
            netCarbs: randomNetCarbs,
            fat: Double.random(in: 5...20),
            protein: Double.random(in: 3...25),
            kcal: Double.random(in: 100...300),
            upc: upc,
            isVerified: false,
            internalReviewNote: "Mock API data",
            isUserCreated: false
        )
    }
}

// MARK: - Singleton

extension UPCSyncCoordinator {
    /// Shared singleton instance
    static let shared = UPCSyncCoordinator()
}
