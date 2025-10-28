import XCTest
@testable import CarbFlow

final class FoodDatabaseSeedTests: XCTestCase {
    private var repository: FoodRepository!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            cf_resetStore()
            repository = FoodRepository()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            repository = nil
        }
        try await super.tearDown()
    }

    func testSeedInstallPopulatesFoodDatabase() async throws {
        await installSeeds(version: 1)
        let firstCount = try await repository.countAll()
        XCTAssertGreaterThan(firstCount, 50)

        await installSeeds(version: 1)
        let secondCount = try await repository.countAll()
        XCTAssertEqual(firstCount, secondCount)
    }

    func testEggSearchReturnsVerifiedSeededItems() async throws {
        await installSeeds(version: 1)
        let results = try await repository.searchFoods(prefix: "egg")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.isVerified }))
    }

    func testSearchPerformanceIsUnder100Milliseconds() async throws {
        await installSeeds(version: 1)

        let start = ContinuousClock.now
        _ = try await repository.searchFoods(prefix: "salmon")
        let duration = ContinuousClock.now - start

        XCTAssertLessThanOrEqual(duration.milliseconds, 100)
    }

    // MARK: Helpers

    private func installSeeds(version: Int64) async {
        let context = await MainActor.run { CFPersistence.shared.newBackgroundContext() }
        CFSeedInstaller.installIfNeeded(
            seedResourceName: "foods_seed_v1",
            seedVersion: version,
            context: context
        )

        await withCheckedContinuation { continuation in
            context.perform {
                continuation.resume()
            }
        }
    }
}

private extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
