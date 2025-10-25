import XCTest
@testable import CarbFlow

final class CFErrorReportingTests: XCTestCase {
    private var originalDestination: CFErrorReportingDestination?
    private var originalEnabled: Bool = true
    private var spy: SpyDestination!

    override func setUpWithError() throws {
        try super.setUpWithError()
        spy = SpyDestination()
        originalDestination = CFErrorReportingRouter.shared.destination
        originalEnabled = CFErrorReportingRouter.shared.enabled
        CFErrorReportingRouter.shared.destination = spy
        CFErrorReportingRouter.shared.enabled = true
    }

    override func tearDownWithError() throws {
        CFErrorReportingRouter.shared.destination = originalDestination ?? ConsoleErrorReportingDestination()
        CFErrorReportingRouter.shared.enabled = originalEnabled
        spy = nil
        try super.tearDownWithError()
    }

    func testReportErrorSendsEvent() {
        cf_reportError(message: "test_error", code: "123", context: ["foo": "bar"])
        waitForEvents()

        XCTAssertEqual(spy.events.count, 1)
        let event = spy.events.first
        XCTAssertEqual(event?.level, .error)
        XCTAssertEqual(event?.message, "test_error")
    }

    func testRedactionRemovesSensitiveKeys() {
        let context: [String: Any] = [
            "token": "secret",
            "note": "should-hide",
            "safe": "value"
        ]
        cf_reportError(message: "redaction_test", context: context)
        waitForEvents()

        let event = spy.events.first
        XCTAssertNotNil(event)
        XCTAssertNil(event?.context["token"])
        XCTAssertNil(event?.context["note"])
        XCTAssertEqual(event?.context["safe"] as? String, "value")
    }

    func testBreadcrumbsIncluded() {
        cf_breadcrumbScreen("Home")
        cf_reportError(message: "with_breadcrumb", context: [:])
        waitForEvents()

        let event = spy.events.first
        let breadcrumbLabels = event?.breadcrumbs.compactMap { $0["label"] as? String }
        XCTAssertEqual(breadcrumbLabels?.last, "Home")
    }

    func testRateLimiterDropsExtraEvents() {
        // Drain the limiter by sending more events than its cap.
        for _ in 0..<10 {
            cf_reportError(message: "rate_test", context: [:])
        }
        waitForEvents()

        // Only the first few (<= maxEvents) should be recorded.
        XCTAssertLessThanOrEqual(spy.events.count, 8)
        XCTAssertGreaterThan(spy.events.count, 0)
    }

    private func waitForEvents(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "Wait for reporter queue")
        DispatchQueue(label: "wait-queue").asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    private final class SpyDestination: CFErrorReportingDestination {
        struct Event {
            let level: CFErrorReportingRouter.Level
            let message: String
            let code: String?
            let context: [String: Any]
            let breadcrumbs: [[String: Any]]
            let timestamp: Date
        }

        private(set) var events: [Event] = []

        func send(level: CFErrorReportingRouter.Level,
                  message: String,
                  code: String?,
                  context: [String : Any],
                  breadcrumbs: [[String : Any]],
                  timestamp: Date) {
            events.append(Event(level: level,
                                message: message,
                                code: code,
                                context: context,
                                breadcrumbs: breadcrumbs,
                                timestamp: timestamp))
        }
    }
}
