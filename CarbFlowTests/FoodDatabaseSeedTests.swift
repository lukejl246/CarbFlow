import XCTest
import CoreData
@testable import CarbFlow

@MainActor
final class FoodDatabaseSeedTests: XCTestCase {
    private var repository: FoodRepository!
    private var persistence: CFPersistence!

    override func setUp() async throws {
        try await super.setUp()
        persistence = CFPersistence.makeInMemory()
        repository = FoodRepository(persistence: persistence)
    }

    override func tearDown() async throws {
        repository = nil
        persistence = nil
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
        let context = persistence.newBackgroundContext()
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
