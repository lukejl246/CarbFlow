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

struct ContentPayload: Codable {
    let contentVersion: Int
    let days: [ContentDay]
}

@MainActor
final class ContentStore: ObservableObject {
    @Published private(set) var days: [ContentDay] = []
    @Published private(set) var contentVersion: Int = 0

    var totalDays: Int {
        let count = days.count
        return count > 0 ? count : 30
    }

    init() {
        loadFromBundle()
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
        loadFromBundle()
        #endif
    }

    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "modules", withExtension: "json") else {
            applyPlaceholder()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let payload = try decoder.decode(ContentPayload.self, from: data)
            apply(payload: payload)
        } catch {
            print("[ContentStore] Failed to load modules.json: \(error)")
            applyPlaceholder()
        }
    }

    private func apply(payload: ContentPayload) {
        let sortedDays = payload.days.sorted(by: { $0.day < $1.day })
        self.days = sortedDays
        self.contentVersion = payload.contentVersion
    }

    private func applyPlaceholder() {
        let placeholderDays = (1...30).map { index -> ContentDay in
            ContentDay(
                day: index,
                title: "Day \(index)",
                summary: "Content will be available soon.",
                keyIdea: "Stay consistent—more lessons are on the way.",
                faqs: [],
                readMins: 2,
                tags: [],
                prerequisites: Array(1..<index),
                requiresCarbTarget: index == 2,
                requiresQuizCorrect: false,
                listRefs: [],
                evidenceIds: []
            )
        }
        self.days = placeholderDays
        self.contentVersion = 0
    }
}
