import XCTest
@testable import CarbFlow

@MainActor
final class FastingLogicTests: XCTestCase {
    func testComputeNewStreakSameDayDoesNotChange() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let todayISO = StreakLogic.todayISO(using: calendar, date: now)

        let result = StreakLogic.computeNewStreak(
            lastISO: todayISO,
            now: now,
            currentStreak: 5,
            calendar: calendar
        )

        XCTAssertEqual(result.newStreak, 5)
        XCTAssertEqual(result.todayISO, todayISO)
    }

    func testComputeNewStreakYesterdayIncrements() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayISO = StreakLogic.todayISO(using: calendar, date: yesterday)

        let result = StreakLogic.computeNewStreak(
            lastISO: yesterdayISO,
            now: now,
            currentStreak: 3,
            calendar: calendar
        )

        XCTAssertEqual(result.newStreak, 4)
    }

    func testComputeNewStreakGapResets() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let oldISO = StreakLogic.todayISO(using: calendar, date: threeDaysAgo)

        let result = StreakLogic.computeNewStreak(
            lastISO: oldISO,
            now: now,
            currentStreak: 5,
            calendar: calendar
        )

        XCTAssertEqual(result.newStreak, 1)
    }

    func testFastingHistoryAppendSortsNewestFirst() {
        let store = FastingHistoryStore()
        store.removeAll()

        let now = Date()
        store.append(start: now.addingTimeInterval(-3600), end: now)
        store.append(start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600))

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertGreaterThanOrEqual(store.sessions[0].start, store.sessions[1].start)
        XCTAssertEqual(store.sessions[0].durationSeconds, 3600)
    }
}
