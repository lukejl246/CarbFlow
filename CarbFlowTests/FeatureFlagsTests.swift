import XCTest
@testable import CarbFlow

final class FeatureFlagsTests: XCTestCase {
    private let suiteName = "cf_test_suite_featureflags"

    override func setUpWithError() throws {
        try super.setUpWithError()
        clearSuite()
    }

    override func tearDownWithError() throws {
        clearSuite()
        try super.tearDownWithError()
    }

    func testDefaultsLoggingIsTrue() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertTrue(flags.isLoggingEnabled, "Logging flag should default to true.")
    }

    func testPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.logging, enabled: false)

        flags = makeFlags(defaults: defaults)
        XCTAssertFalse(flags.isLoggingEnabled, "Logging flag should persist as false across instances.")
    }

    func testResetRestoresDefaults() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.logging, enabled: false)

        flags.resetToDefaults()

        XCTAssertTrue(flags.isLoggingEnabled, "resetToDefaults should restore logging flag to true.")
    }

    func testRecipesDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isRecipesEnabled, "Recipes flag should default to false.")
    }

    func testRecipesPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.recipes, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isRecipesEnabled, "Recipes flag should persist as true across instances.")
    }

    func testResetRestoresRecipesDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.recipes, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isRecipesEnabled, "resetToDefaults should restore recipes flag to false.")
    }

    func testHealthKitDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isHealthKitEnabled, "HealthKit flag should default to false.")
    }

    func testHealthKitPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.healthKit, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isHealthKitEnabled, "HealthKit flag should persist as true across instances.")
    }

    func testResetRestoresHealthKitDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.healthKit, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isHealthKitEnabled, "resetToDefaults should restore HealthKit flag to false.")
    }

    func testWearablesDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isWearablesEnabled, "Wearables flag should default to false.")
    }

    func testWearablesPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.wearables, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isWearablesEnabled, "Wearables flag should persist as true across instances.")
    }

    func testResetRestoresWearablesDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.wearables, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isWearablesEnabled, "resetToDefaults should restore Wearables flag to false.")
    }

    func testKetonesDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isKetonesEnabled, "Ketones flag should default to false.")
    }

    func testKetonesPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.ketones, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isKetonesEnabled, "Ketones flag should persist as true across instances.")
    }

    func testResetRestoresKetonesDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.ketones, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isKetonesEnabled, "resetToDefaults should restore Ketones flag to false.")
    }

    func testCoachDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isCoachEnabled, "Coach flag should default to false.")
    }

    func testCoachPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.coach, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isCoachEnabled, "Coach flag should persist as true across instances.")
    }

    func testResetRestoresCoachDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.coach, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isCoachEnabled, "resetToDefaults should restore Coach flag to false.")
    }

    func testQuizzesDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isQuizzesEnabled, "Quizzes flag should default to false.")
    }

    func testQuizzesPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.quizzes, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isQuizzesEnabled, "Quizzes flag should persist as true across instances.")
    }

    func testResetRestoresQuizzesDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.quizzes, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isQuizzesEnabled, "resetToDefaults should restore Quizzes flag to false.")
    }

    func testProgrammeDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isProgrammeEnabled, "Programme flag should default to false.")
    }

    func testProgrammePersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.programme, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isProgrammeEnabled, "Programme flag should persist as true across instances.")
    }

    func testResetRestoresProgrammeDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.programme, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isProgrammeEnabled, "resetToDefaults should restore Programme flag to false.")
    }

    func testChallengesDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isChallengesEnabled, "Challenges flag should default to false.")
    }

    func testChallengesPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.challenges, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isChallengesEnabled, "Challenges flag should persist as true across instances.")
    }

    func testResetRestoresChallengesDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.challenges, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isChallengesEnabled, "resetToDefaults should restore Challenges flag to false.")
    }

    func testFastingDefaultIsFalse() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        XCTAssertFalse(flags.isFastingEnabled, "Fasting flag should default to false.")
    }

    func testFastingPersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        flags.set(.fasting, enabled: true)

        flags = makeFlags(defaults: defaults)
        XCTAssertTrue(flags.isFastingEnabled, "Fasting flag should persist as true across instances.")
    }

    func testResetRestoresFastingDefault() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)
        flags.set(.fasting, enabled: true)

        flags.resetToDefaults()

        XCTAssertFalse(flags.isFastingEnabled, "resetToDefaults should restore Fasting flag to false.")
    }

    func testDashboardTileDefaults() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        for (flag, expected) in dashboardDefaultExpectations {
            XCTAssertEqual(flags.isEnabled(flag), expected, "\(flag) should default to \(expected).")
        }
    }

    func testDashboardTilePersistenceAcrossInstances() throws {
        let defaults = try makeDefaults()
        var flags = makeFlags(defaults: defaults)
        let overrides: [(FeatureFlag, Bool)] = [
            (.dashboardSummary, false),
            (.dashboardTrends, true),
            (.dashboardStreaks, true),
            (.dashboardMacros, true),
            (.dashboardHydration, true),
            (.dashboardSleep, true),
            (.dashboardReadiness, true)
        ]

        overrides.forEach { flag, value in
            flags.set(flag, enabled: value)
        }

        flags = makeFlags(defaults: defaults)

        overrides.forEach { flag, expected in
            XCTAssertEqual(flags.isEnabled(flag), expected, "\(flag) should persist as \(expected).")
        }
    }

    func testDashboardTileResetRestoresDefaults() throws {
        let defaults = try makeDefaults()
        let flags = makeFlags(defaults: defaults)

        let overrides: [(FeatureFlag, Bool)] = [
            (.dashboardSummary, false),
            (.dashboardTrends, true),
            (.dashboardStreaks, true),
            (.dashboardMacros, true),
            (.dashboardHydration, true),
            (.dashboardSleep, true),
            (.dashboardReadiness, true)
        ]

        overrides.forEach { flag, value in
            flags.set(flag, enabled: value)
        }

        flags.resetToDefaults()

        for (flag, expected) in dashboardDefaultExpectations {
            XCTAssertEqual(flags.isEnabled(flag), expected, "Reset should restore \(flag) to \(expected).")
        }
    }

    // MARK: - Helpers

    private func makeDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create UserDefaults with suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
        return defaults
    }

    private func makeFlags(defaults: UserDefaults) -> CFFeatureFlags {
        CFFeatureFlags(defaults: defaults)
    }

    private func clearSuite() {
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.synchronize()
        }
    }

    private let dashboardDefaultExpectations: [(FeatureFlag, Bool)] = [
        (.dashboardSummary, true),
        (.dashboardTrends, false),
        (.dashboardStreaks, false),
        (.dashboardMacros, false),
        (.dashboardHydration, false),
        (.dashboardSleep, false),
        (.dashboardReadiness, false)
    ]
}
