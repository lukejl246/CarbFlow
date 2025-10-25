import Foundation
import Combine

@MainActor
final class QuizEngine: ObservableObject {
    enum SubmissionFailure: Equatable {
        case missingSelection
        case invalidSelection
        case missingContent
        case scoringMismatch
    }

    enum SubmissionResult: Equatable {
        case success(isCorrect: Bool)
        case failure(SubmissionFailure)
    }

    private(set) var quiz: Quiz
    private var hasStarted = false
    private var didWarnAboutContent = false

    init(quiz: Quiz) {
        self.quiz = quiz
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        cf_breadcrumbAction("quiz_start", data: baseBreadcrumbData)

        if quiz.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quiz.options.isEmpty {
            emitContentWarning(reason: quiz.options.isEmpty ? "no_options" : "empty_question")
        } else if quiz.correctIndex < 0 || quiz.correctIndex >= quiz.options.count {
            emitContentWarning(reason: "invalid_correct_index")
        }
    }

    func submit(selection index: Int?) -> SubmissionResult {
        cf_breadcrumbAction("quiz_submit", data: baseBreadcrumbData)

        guard !quiz.options.isEmpty else {
            emitSubmissionError(code: "no_options")
            return .failure(.missingContent)
        }

        guard quiz.correctIndex >= 0, quiz.correctIndex < quiz.options.count else {
            emitSubmissionError(code: "invalid_correct_index")
            return .failure(.scoringMismatch)
        }

        guard let index = index else {
            return .failure(.missingSelection)
        }

        guard index >= 0, index < quiz.options.count else {
            emitSubmissionError(code: "invalid_selection")
            return .failure(.invalidSelection)
        }

        let isCorrect = index == quiz.correctIndex
        return .success(isCorrect: isCorrect)
    }

    private var quizIdentifier: String {
        String(quiz.day)
    }

    private var baseBreadcrumbData: [String: Any] {
        ["quiz_id": quizIdentifier]
    }

    private var baseContext: [String: Any] {
        ["quiz_id": quizIdentifier]
    }

    private func emitContentWarning(reason: String) {
        guard !didWarnAboutContent else { return }
        didWarnAboutContent = true
        var context = baseContext
        context["reason"] = reason
        cf_reportWarning(message: "quiz_content_missing", context: context)
    }

    private func emitSubmissionError(code: String) {
        cf_reportError(message: "quiz_submit_failed", code: code, context: baseContext)
    }
}
