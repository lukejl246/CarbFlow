import XCTest
import CoreData
@testable import CarbFlow

final class UserFoodTests: XCTestCase {
    private var persistence: CFPersistence!
    private var userRepository: UserFoodRepository!
    private var foodRepository: FoodRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = CFPersistence.makeInMemory()
        userRepository = UserFoodRepository(persistence: persistence)
        foodRepository = FoodRepository(persistence: persistence)
        cleanupOfflineLog()
    }

    override func tearDownWithError() throws {
        persistence = nil
        userRepository = nil
        foodRepository = nil
        cleanupOfflineLog()
        try super.tearDownWithError()
    }

    func testCreateAndFetchBySlug() async throws {
        let input = NewUserFoodInput(
            name: "Test Granola",
            brand: "KitchenLab",
            servingSizeValue: 45,
            servingSizeUnit: "g",
            netCarbsPer100g: 32,
            proteinPer100g: 12,
            fatPer100g: 10,
            notes: "Crunchy"
        )

        let saved = try await userRepository.create(input)
        XCTAssertTrue(saved.isUserCreated)
        XCTAssertEqual(saved.source, "user")
        guard let slug = saved.slug else {
            XCTFail("Expected slug to be generated")
            return
        }

        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "slug == %@", slug)
        request.fetchLimit = 1
        let fetched = try persistence.viewContext.fetch(request).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, normaliseName(input.name))
        XCTAssertEqual(fetched?.brand, normaliseName(input.brand ?? ""))
        XCTAssertEqual(fetched?.netCarbsPer100g, input.netCarbsPer100g)
        XCTAssertEqual(fetched?.proteinPer100g, input.proteinPer100g)
        XCTAssertEqual(fetched?.fatPer100g, input.fatPer100g)
        XCTAssertEqual(fetched?.servingSizeUnit, input.servingSizeUnit)
        XCTAssertEqual(fetched?.servingSizeValue as? Double, input.servingSizeValue)
    }

    func testUpdateRespectsLatestTimestampAndMergePolicy() async throws {
        let initial = try await userRepository.create(
            NewUserFoodInput(
                name: "Homemade Yoghurt",
                brand: "Kitchen",
                servingSizeValue: 120,
                servingSizeUnit: "g",
                netCarbsPer100g: 5,
                proteinPer100g: 6,
                fatPer100g: 3,
                notes: nil
            )
        )

        let objectID = initial.objectID
        guard let uuid = initial.id else {
            XCTFail("Missing identifiers")
            return
        }

        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()

        let patchOld = FoodPatch(
            name: "Homemade Greek Yoghurt",
            brand: .set("KitchenLab"),
            servingSizeValue: .set(140),
            servingSizeUnit: .set("g"),
            netCarbsPer100g: 4,
            proteinPer100g: 9,
            fatPer100g: 4,
            notes: .set("Strained"),
            updatedAt: olderDate
        )

        try await userRepository.update(id: objectID, with: patchOld)

        let afterOld = try persistence.viewContext.existingObject(with: objectID) as! Food
        XCTAssertEqual(afterOld.updatedAt, olderDate)
        XCTAssertEqual(afterOld.netCarbsPer100g, 4)
        XCTAssertEqual(afterOld.proteinPer100g, 9)

        let patchNew = FoodPatch(
            name: "Homemade Greek Yoghurt",
            brand: .set("KitchenLab"),
            servingSizeValue: .set(150),
            servingSizeUnit: .set("g"),
            netCarbsPer100g: 3,
            proteinPer100g: 11,
            fatPer100g: 4,
            notes: .set("Double strained"),
            updatedAt: newerDate
        )

        try await userRepository.update(id: objectID, with: patchNew)

        let afterNew = try persistence.viewContext.existingObject(with: objectID) as! Food
        XCTAssertEqual(afterNew.updatedAt, newerDate)
        XCTAssertEqual(afterNew.netCarbsPer100g, 3)
        XCTAssertEqual(afterNew.proteinPer100g, 11)

        guard let slug = afterNew.slug else {
            XCTFail("Missing slug")
            return
        }

        let dtoOld = FoodDTO(
            id: uuid,
            name: afterNew.name ?? "",
            brand: afterNew.brand,
            slug: slug,
            isUserCreated: true,
            notes: afterNew.notes,
            source: afterNew.source ?? "user",
            updatedAt: olderDate
        )

        let dtoNew = FoodDTO(
            id: uuid,
            name: afterNew.name ?? "",
            brand: afterNew.brand,
            slug: slug,
            isUserCreated: true,
            notes: afterNew.notes,
            source: afterNew.source ?? "user",
            updatedAt: newerDate
        )

        let merged = CFLocalMergePolicy().resolveConflicts([
            .update(id: uuid, dtoOld),
            .update(id: uuid, dtoNew)
        ])

        XCTAssertEqual(merged.count, 1)
        if case let .update(_, finalDTO) = merged.first! {
            XCTAssertEqual(finalDTO.updatedAt, newerDate)
        } else {
            XCTFail("Expected update operation after merge")
        }
    }

    func testSoftDeleteAndHardPurge() async throws {
        let created = try await userRepository.create(
            NewUserFoodInput(
                name: "Smoky Chili",
                brand: "Family",
                servingSizeValue: 250,
                servingSizeUnit: "g",
                netCarbsPer100g: 8,
                proteinPer100g: 14,
                fatPer100g: 9,
                notes: nil
            )
        )

        let objectID = created.objectID
        guard let name = created.name else {
            XCTFail("Missing identifiers")
            return
        }

        var initialResults = try await foodRepository.searchFoods(prefix: name, limit: 5)
        XCTAssertFalse(initialResults.isEmpty, "Expected item to appear before soft delete")

        try await userRepository.softDelete(id: objectID)
        let postDeleteResults = try await foodRepository.searchFoods(prefix: name, limit: 5)
        XCTAssertTrue(postDeleteResults.isEmpty, "Soft-deleted foods should not appear in search")

        try await userRepository.hardPurgeDeleted()
        XCTAssertThrowsError(try persistence.viewContext.existingObject(with: objectID))
    }

    func testOfflineQueueReplayIsIdempotent() async throws {
        let offlineOps = CFOfflineFoodOps(persistence: persistence, repository: userRepository)

        // Queue operations: create new item, update an existing one.
        let queuedCreate = NewUserFoodInput(
            name: "Offline Granola",
            brand: "Batch",
            servingSizeValue: 60,
            servingSizeUnit: "g",
            netCarbsPer100g: 40,
            proteinPer100g: 8,
            fatPer100g: 12,
            notes: nil
        )
        await offlineOps.queueCreate(queuedCreate)

        let existing = try await userRepository.create(
            NewUserFoodInput(
                name: "Offline Smoothie",
                brand: "Kitchen",
                servingSizeValue: 300,
                servingSizeUnit: "ml",
                netCarbsPer100g: 9,
                proteinPer100g: 5,
                fatPer100g: 4,
                notes: nil
            )
        )

        guard let existingUUID = existing.id else {
            XCTFail("Missing UUID on existing food")
            return
        }

        let updatePatch = FoodPatch(
            name: nil,
            brand: .set("Kitchen Updated"),
            servingSizeValue: .set(320),
            servingSizeUnit: .set("ml"),
            netCarbsPer100g: 7,
            proteinPer100g: 7,
            fatPer100g: 5,
            notes: .set("Blended twice"),
            updatedAt: Date()
        )

        await offlineOps.queueUpdate(id: existingUUID, mutate: updatePatch)

        // First replay should apply operations.
        await offlineOps.replayPendingOperations()

        let createdFetch = try fetchFoods(named: "Offline Granola")
        XCTAssertEqual(createdFetch.count, 1)
        XCTAssertEqual(createdFetch.first?.brand, normaliseName("Batch"))

        if let updated = try fetchFoods(named: "Offline Smoothie").first {
            XCTAssertEqual(updated.brand, normaliseName("Kitchen Updated"))
            XCTAssertEqual(updated.servingSizeUnit, "ml")
            XCTAssertEqual(updated.servingSizeValue as? Double, 320)
            XCTAssertEqual(updated.proteinPer100g, 7)
        } else {
            XCTFail("Expected updated smoothie to exist")
        }

        // Queue the same operations again to simulate a crash before clearing.
        await offlineOps.queueCreate(queuedCreate)
        await offlineOps.queueUpdate(id: existingUUID, mutate: updatePatch)
        await offlineOps.replayPendingOperations()

        let postReplayCreated = try fetchFoods(named: "Offline Granola")
        XCTAssertEqual(postReplayCreated.count, 1, "Create should be idempotent after duplicate replay")

        if let postReplayUpdated = try fetchFoods(named: "Offline Smoothie").first {
            XCTAssertEqual(postReplayUpdated.brand, normaliseName("Kitchen Updated"))
            XCTAssertEqual(postReplayUpdated.proteinPer100g, 7)
        } else {
            XCTFail("Expected smoothie to remain after second replay")
        }
    }

    func testCreateAndUpdatePerformanceUnderThreshold() async throws {
        let iterations = 5
        var durations: [TimeInterval] = []

        for index in 0..<iterations {
            let name = "Perf Item \(index)"
            let input = NewUserFoodInput(
                name: name,
                brand: "Perf",
                servingSizeValue: 50,
                servingSizeUnit: "g",
                netCarbsPer100g: 20,
                proteinPer100g: 10,
                fatPer100g: 8,
                notes: nil
            )

            let start = Date()
            let saved = try await userRepository.create(input)
            let patch = FoodPatch(
                name: nil,
                brand: nil,
                servingSizeValue: nil,
                servingSizeUnit: nil,
                netCarbsPer100g: 18,
                proteinPer100g: 12,
                fatPer100g: 7,
                notes: nil,
                updatedAt: Date()
            )
            try await userRepository.update(id: saved.objectID, with: patch)
            let end = Date()
            durations.append(end.timeIntervalSince(start))
        }

        let average = durations.reduce(0, +) / Double(durations.count)
        XCTAssertLessThan(average, 0.150, "Average create/edit flow should be under 150 ms (was \(average))")
    }

    // MARK: - Helpers

    private func fetchFoods(named name: String) throws -> [Food] {
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", normaliseName(name))
        return try persistence.viewContext.fetch(request)
    }

    private func cleanupOfflineLog() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let directory = base.appendingPathComponent("CarbFlow", isDirectory: true)
        let url = directory.appendingPathComponent("cf_food_ops.jsonl")
        try? fm.removeItem(at: url)
    }
}
