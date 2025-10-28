import XCTest
@testable import CarbFlow

@MainActor
final class WhatsNewTests: XCTestCase {
    private let suiteName = "cf_test_suite_whatsnew"
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        userDefaults = defaults
    }

    override func tearDownWithError() throws {
        if let defaults = userDefaults {
            defaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        try super.tearDownWithError()
    }

    func testDefaultsPresent() {
        let store = WhatsNewStore(userDefaults: userDefaults)
        XCTAssertTrue(store.shouldPresent, "The What's New sheet should be presented on first launch.")
    }

    func testMarksSeenPreventsPresentation() {
        let store = WhatsNewStore(userDefaults: userDefaults)
        store.markSeen()

        let nextStore = WhatsNewStore(userDefaults: userDefaults)
        XCTAssertFalse(nextStore.shouldPresent, "After marking seen, the sheet should not present again.")
    }

    func testNewVersionTriggersPresentation() {
        userDefaults.set("old-version", forKey: CFKeys.whatsNewLastSeen)

        let store = WhatsNewStore(userDefaults: userDefaults)
        XCTAssertTrue(store.shouldPresent, "When a stored version differs from current, presentation should be triggered.")
    }
}
