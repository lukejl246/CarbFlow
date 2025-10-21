import Foundation

struct UnlockContext {
    let currentDay: Int
    let hasSetCarbTarget: Bool
    let quizCorrectDays: Set<Int>
}

enum UnlockRules {
    static func canOpen(day targetDay: Int, content: ContentStore, ctx: UnlockContext) -> (allowed: Bool, reason: String?) {
        guard targetDay <= content.totalDays else {
            return (false, "This day isn’t available yet.")
        }

        guard let contentDay = content.day(targetDay) else {
            return (false, "Content not found.")
        }

        if let unmet = contentDay.prerequisites
            .filter({ $0 <= content.totalDays })
            .first(where: { ctx.currentDay < $0 }) {
            return (false, reasonForLock(prerequisiteDay: unmet))
        }

        if targetDay > ctx.currentDay {
            return (false, reasonForLock(prerequisiteDay: ctx.currentDay))
        }

        return (true, nil)
    }

    static func reasonForLock(prerequisiteDay: Int) -> String {
        "Complete Day \(prerequisiteDay) first."
    }
}
