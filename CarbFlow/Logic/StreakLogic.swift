import Foundation

enum StreakLogic {
    /// Returns an ISO8601 string (yyyy-MM-dd) for the provided date using the given calendar.
    /// Uses `.withFullDate` so clock changes within the same day do not affect the identifier.
    static func todayISO(using calendar: Calendar = .current, date: Date = Date()) -> String {
        let formatter = isoDayFormatter
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    /// Determines whether two dates fall on the same calendar day.
    static func isSameCalendarDay(_ d1: Date, _ d2: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(d1, inSameDayAs: d2)
    }

    /// Calculates the next streak value based on the last completion date string and the current date.
    ///
    /// - Parameters:
    ///   - lastISO: ISO8601 full-date string of the last completion (yyyy-MM-dd). Nil if none.
    ///   - now: The current date to evaluate streak progression against.
    ///   - calendar: Calendar used for day boundaries (defaults to `.current`).
    /// - Returns: A tuple containing the new streak count and today's ISO string.
    ///
    /// Behaviour:
    /// - If `lastISO` refers to the same calendar day as `now`, the streak remains unchanged.
    /// - If `lastISO` refers to yesterday relative to `now`, the streak increases by 1.
    /// - Otherwise the streak resets to 1.
    /// The logic relies on the provided calendar, so behaviour during clock changes follows device settings.
    static func computeNewStreak(
        lastISO: String?,
        now: Date = Date(),
        currentStreak: Int,
        calendar: Calendar = .current
    ) -> (newStreak: Int, todayISO: String) {
        let todayISOString = todayISO(using: calendar, date: now)
        guard let lastISO else {
            return (max(currentStreak, 1), todayISOString)
        }

        if lastISO == todayISOString {
            return (currentStreak, todayISOString)
        }

        let formatter = isoDayFormatter
        formatter.timeZone = calendar.timeZone
        guard let lastDate = formatter.date(from: lastISO) else {
            return (1, todayISOString)
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           isSameCalendarDay(lastDate, yesterday, calendar: calendar) {
            return (max(currentStreak, 0) + 1, todayISOString)
        }

        return (1, todayISOString)
    }

    private static var isoDayFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }
}
