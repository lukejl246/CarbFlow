import XCTest
import CoreData
@testable import CarbFlow

final class FoodStoreTests: XCTestCase {
    private var persistence: PersistenceController!
    private var store: FoodStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        store = FoodStore(context: persistence.container.viewContext)
        FoodSeedLoader.seedIfNeeded(persistence: persistence)
        try waitForSeed()
    }

    override func tearDownWithError() throws {
        persistence = nil
        store = nil
        try super.tearDownWithError()
    }

    func testSeedInsertsExpectedCount() throws {
        let items = store.all(limit: 200)
        XCTAssertGreaterThanOrEqual(items.count, 25, "Expected seed to insert at least 25 items")
    }

    func testSearchReturnsMatches() throws {
        let results = store.search("egg", limit: 10)
        XCTAssertFalse(results.isEmpty, "Search should find egg items")
        XCTAssertLessThanOrEqual(results.count, 10)
        XCTAssertTrue(results.contains { $0.name.lowercased().contains("egg") || ($0.brand?.lowercased().contains("egg") ?? false) })
    }

    func testItemForUPC() throws {
        let knownUPC = "0040000085247"
        let item = store.item(forUPC: knownUPC)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.upc, knownUPC)

        XCTAssertNil(store.item(forUPC: "0000000000000"))
    }

    private func waitForSeed() throws {
        let ctx = persistence.container.viewContext
        ctx.performAndWait {
            _ = try? ctx.fetch(FoodItem.fetchRequest())
        }
    }
}
