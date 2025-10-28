import XCTest
@testable import CarbFlow

@MainActor
final class AnalyticsTests: XCTestCase {
    private var originalDestination: AnalyticsDestination?
    private var originalEnabled: Bool = true
    private var spy: SpyDestination!

    override func setUpWithError() throws {
        try super.setUpWithError()
        spy = SpyDestination()
        originalDestination = AnalyticsRouter.destination
        originalEnabled = AnalyticsRouter.enabled
        AnalyticsRouter.destination = spy
        AnalyticsRouter.enabled = true
    }

    override func tearDownWithError() throws {
        AnalyticsRouter.destination = originalDestination ?? ConsoleAnalyticsDestination()
        AnalyticsRouter.enabled = originalEnabled
        spy = nil
        try super.tearDownWithError()
    }

    func testScreenViewLogsScreenName() {
        logScreenView(screenName: "home")

        XCTAssertEqual(spy.events.count, 1)
        XCTAssertEqual(spy.events.first?.name, AnalyticsEventNames.screenView)
        XCTAssertEqual(spy.events.first?.params["screen_name"] as? String, "home")
    }

    func testFoodLoggedIncludesCarbs() {
        logFoodLogged(carbsGrams: 45.5)

        XCTAssertEqual(spy.events.count, 1)
        XCTAssertEqual(spy.events.first?.name, AnalyticsEventNames.foodLogged)
        XCTAssertEqual(spy.events.first?.params["carbs_g"] as? Double, 45.5)
    }

    func testFastStoppedIncludesDuration() {
        logFastStopped(durationSeconds: 3600)

        XCTAssertEqual(spy.events.count, 1)
        XCTAssertEqual(spy.events.first?.name, AnalyticsEventNames.fastStopped)
        XCTAssertEqual(spy.events.first?.params["duration_s"] as? Int, 3600)
    }

    func testQuizCompletedIncludesQuizId() {
        logQuizCompleted(quizId: "fasting101", score: 80)

        XCTAssertEqual(spy.events.count, 1)
        XCTAssertEqual(spy.events.first?.name, AnalyticsEventNames.quizCompleted)
        XCTAssertEqual(spy.events.first?.params["quiz_id"] as? String, "fasting101")
    }

    private final class SpyDestination: AnalyticsDestination {
        struct Event {
            let name: String
            let params: [String: Any]
        }

        private(set) var events: [Event] = []

        func send(name: String, params: [String : Any]) {
            events.append(Event(name: name, params: params))
        }
    }
}
