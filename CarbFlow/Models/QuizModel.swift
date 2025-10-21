import SwiftUI
import Combine

struct Quiz: Identifiable, Codable, Equatable {
    var id: Int { day }
    let day: Int
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String?

    init(day: Int, question: String, options: [String], correctIndex: Int, explanation: String?) {
        self.day = day
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

struct QuizPayload: Codable {
    let quizzes: [Quiz]
}

@MainActor
final class QuizStore: ObservableObject {
    @Published private(set) var quizzes: [Quiz] = []
    @AppStorage("cf_quizCorrectDays") private var correctDaysStorage: String = "[]"

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(contentStore: ContentStore) {
        loadQuizzes(contentStore: contentStore)
        cleanPersistedCorrectDays(contentStore: contentStore)
    }

    func quiz(for day: Int) -> Quiz? {
        quizzes.first(where: { $0.day == day })
    }

    func markCorrect(day: Int) {
        objectWillChange.send()
        var set = Set(correctDays())
        set.insert(day)
        save(correctDays: Array(set))
    }

    func resetProgress() {
        objectWillChange.send()
        save(correctDays: [])
    }

    func isCorrect(day: Int) -> Bool {
        correctDays().contains(day)
    }

    func correctDaysSet() -> Set<Int> {
        Set(correctDays())
    }

    private func correctDays() -> [Int] {
        guard let data = correctDaysStorage.data(using: .utf8) else { return [] }
        do {
            let values = try decoder.decode([Int].self, from: data)
            return values
        } catch {
            return []
        }
    }

    private func save(correctDays: [Int]) {
        do {
            let data = try encoder.encode(correctDays.sorted())
            correctDaysStorage = String(decoding: data, as: UTF8.self)
        } catch {
            // ignore encoding errors for now
        }
    }

    private func loadQuizzes(contentStore: ContentStore) {
        guard let url = Bundle.main.url(forResource: "quizzes", withExtension: "json") else {
            quizzes = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try decoder.decode(QuizPayload.self, from: data)
            quizzes = payload.quizzes.filter { $0.day <= contentStore.totalDays }
        } catch {
            quizzes = []
        }
    }

    private func cleanPersistedCorrectDays(contentStore: ContentStore) {
        let validDays = Set(1...contentStore.totalDays)
        let current = correctDays()
        let filtered = current.filter { validDays.contains($0) }
        if filtered.count != current.count {
            objectWillChange.send()
        }
        save(correctDays: filtered)
    }
}
