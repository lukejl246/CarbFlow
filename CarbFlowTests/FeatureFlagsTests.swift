import XCTest
@testable import CarbFlow

final class FeatureFlagsTests: XCTestCase {
    private var snapshot: [FeatureFlag: Bool] = [:]

    override func setUpWithError() throws {
        try super.setUpWithError()
        snapshot = FeatureFlag.allCases.reduce(into: [:]) { result, flag in
            result[flag] = CFFeatureFlags.shared.isEnabled(flag)
        }
        CFFeatureFlags.shared.resetToDefaults()
    }

    override func tearDownWithError() throws {
        for (flag, value) in snapshot {
            CFFeatureFlags.shared.set(flag, enabled: value)
        }
        snapshot.removeAll()
        try super.tearDownWithError()
    }

    func testLoggingDefaultsToTrue() {
        XCTAssertTrue(CFFeatureFlags.shared.isEnabled(.logging))
    }

    func testSettingFlagPersists() {
        CFFeatureFlags.shared.set(.recipes, enabled: true)
        XCTAssertTrue(CFFeatureFlags.shared.isEnabled(.recipes))
    }

    func testResetRestoresDefaults() {
        CFFeatureFlags.shared.set(.wearables, enabled: true)
        CFFeatureFlags.shared.resetToDefaults()

        XCTAssertTrue(CFFeatureFlags.shared.isEnabled(.logging))
        XCTAssertFalse(CFFeatureFlags.shared.isEnabled(.wearables))
    }
}
