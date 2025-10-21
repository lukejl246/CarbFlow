import Foundation

struct TodayMetrics {
    let currentDay: Int
    let totalDays: Int
    let streakCount: Int
    let streakHint: String
    let readMinutes: Int
    let hasPendingQuiz: Bool
    let quizMessage: String
    let pendingRequirements: [Requirement]

    enum Requirement: Identifiable, Equatable {
        case quiz
        case carbTarget

        var id: String {
            switch self {
            case .quiz: return "quiz"
            case .carbTarget: return "carb"
            }
        }

        var label: String {
            switch self {
            case .quiz:
                return "Complete quiz"
            case .carbTarget:
                return "Set carb target"
            }
        }
    }
}

struct HomeMetricsBuilder {
    static func make(currentDay: Int,
                     streakCount: Int,
                     totalDays: Int,
                     readMinutes: Int,
                     requiresQuiz: Bool,
                     quizIsSatisfied: Bool,
                     requiresCarbTarget: Bool,
                     hasCarbSelection: Bool) -> TodayMetrics {
        let clampedDay = min(max(currentDay, 1), max(totalDays, 1))
        let streakHint: String
        if streakCount == 0 {
            streakHint = "Complete today to start your streak."
        } else if streakCount < 7 {
            streakHint = "Keep going—consistency builds results."
        } else {
            let weeks = streakCount / 7
            streakHint = "≈ \(weeks) week\(weeks == 1 ? "" : "s") of momentum."
        }

        var requirements: [TodayMetrics.Requirement] = []
        if requiresQuiz && !quizIsSatisfied {
            requirements.append(.quiz)
        }
        if requiresCarbTarget && !hasCarbSelection {
            requirements.append(.carbTarget)
        }

        return TodayMetrics(
            currentDay: clampedDay,
            totalDays: max(totalDays, 1),
            streakCount: max(streakCount, 0),
            streakHint: streakHint,
            readMinutes: readMinutes,
            hasPendingQuiz: requiresQuiz && !quizIsSatisfied,
            quizMessage: quizIsSatisfied ? "Quiz completed." : (requiresQuiz ? "Take the quick quiz before completing." : ""),
            pendingRequirements: requirements
        )
    }
}
