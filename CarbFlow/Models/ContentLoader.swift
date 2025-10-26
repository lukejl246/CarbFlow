import Foundation
import Combine

struct ContentDay: Identifiable, Codable, Equatable {
    let id: Int
    let day: Int
    let title: String
    let summary: String
    let keyIdea: String
    let faqs: [String]
    let readMins: Int
    let tags: [String]
    let prerequisites: [Int]
    let requiresCarbTarget: Bool
    let requiresQuizCorrect: Bool
    let listRefs: [String]
    let evidenceIds: [String]

    init(
        day: Int,
        title: String,
        summary: String,
        keyIdea: String,
        faqs: [String],
        readMins: Int,
        tags: [String],
        prerequisites: [Int],
        requiresCarbTarget: Bool,
        requiresQuizCorrect: Bool,
        listRefs: [String],
        evidenceIds: [String]
    ) {
        self.id = day
        self.day = day
        self.title = title
        self.summary = summary
        self.keyIdea = keyIdea
        self.faqs = faqs
        self.readMins = readMins
        self.tags = tags
        self.prerequisites = prerequisites
        self.requiresCarbTarget = requiresCarbTarget
        self.requiresQuizCorrect = requiresQuizCorrect
        self.listRefs = listRefs
        self.evidenceIds = evidenceIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let day = try container.decode(Int.self, forKey: .day)
        self.id = day
        self.day = day
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.keyIdea = try container.decode(String.self, forKey: .keyIdea)
        self.faqs = try container.decode([String].self, forKey: .faqs)
        self.readMins = try container.decode(Int.self, forKey: .readMins)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.prerequisites = try container.decode([Int].self, forKey: .prerequisites)
        self.requiresCarbTarget = try container.decode(Bool.self, forKey: .requiresCarbTarget)
        self.requiresQuizCorrect = try container.decode(Bool.self, forKey: .requiresQuizCorrect)
        self.listRefs = try container.decode([String].self, forKey: .listRefs)
        self.evidenceIds = try container.decode([String].self, forKey: .evidenceIds)
    }
}

@MainActor
final class ContentStore: ObservableObject {
    @Published private(set) var days: [ContentDay] = []
    @Published private(set) var contentVersion: Int = 0

    var totalDays: Int {
        let count = days.count
        return count > 0 ? count : 1
    }

    init() {
        loadDefaultContent()
    }

    func day(_ day: Int) -> ContentDay? {
        days.first(where: { $0.day == day })
    }

    func title(for dayNumber: Int) -> String {
        day(dayNumber)?.title ?? "Day \(dayNumber)"
    }

    func summary(for dayNumber: Int) -> String {
        day(dayNumber)?.summary ?? "Summary coming soon."
    }

    func refreshFromBundle() {
        #if DEBUG
        loadDefaultContent()
        #endif
    }

    private func loadDefaultContent() {
        let overview = ContentDay(
            day: 1,
            title: "Daily Overview",
            summary: "Check in each day to review habits and plan your next step.",
            keyIdea: "Tiny adjustments add up. Capture how you're feeling and pick one focus.",
            faqs: [
                "How often should I check in? Once per day works for most people.",
                "What should I record? Simple notes about meals, energy, or goals."
            ],
            readMins: 1,
            tags: [],
            prerequisites: [],
            requiresCarbTarget: false,
            requiresQuizCorrect: false,
            listRefs: [],
            evidenceIds: []
        )

        self.days = [overview]
        self.contentVersion = 1
    }
}
