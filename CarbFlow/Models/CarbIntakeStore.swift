import SwiftUI
@preconcurrency import Combine

struct CarbEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let grams: Int
    let note: String?
    let timestamp: Date

    init(id: UUID = UUID(), grams: Int, note: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.grams = grams
        self.note = note
        self.timestamp = timestamp
    }
}

@MainActor
final class CarbIntakeStore: ObservableObject {
    @Published private(set) var entries: [CarbEntry] = []
    @Published private(set) var dayISO: String

    @AppStorage(Keys.carbEntriesJSON) private var storedEntriesJSON: String = "[]"
    @AppStorage(Keys.carbEntriesDateISO) private var storedDayISO: String = ""

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(now: Date = Date()) {
        let today = Self.isoFormatter.string(from: now)
        self.dayISO = today

        if storedDayISO == today,
           let data = storedEntriesJSON.data(using: .utf8),
           let decoded = try? decoder.decode([CarbEntry].self, from: data) {
            self.entries = decoded.sorted { $0.timestamp > $1.timestamp }
        } else {
            reset(for: today)
        }
    }

    var total: Int {
        entries.reduce(0) { $0 + $1.grams }
    }

    func gramsLeft(target: Int) -> Int {
        max(0, target - total)
    }

    func add(grams: Int, note: String? = nil, timestamp: Date = Date()) {
        guard grams > 0 else { return }
        ensureDayIsCurrent(using: timestamp)

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = (trimmedNote?.isEmpty == false) ? trimmedNote : nil
        let entry = CarbEntry(grams: grams, note: normalizedNote, timestamp: timestamp)
        var updated = entries
        updated.insert(entry, at: 0)
        entries = updated
        save()
        logFoodLogged(
            carbsGrams: Double(entry.grams),
            meal: entry.note,
            at: entry.timestamp
        )
    }

    func remove(_ id: UUID) {
        let updated = entries.filter { $0.id != id }
        guard updated.count != entries.count else { return }
        entries = updated
        save()
    }

    func clearToday() {
        reset(for: currentDayISO())
    }

    func refreshIfNeeded(now: Date = Date()) {
        let today = Self.isoFormatter.string(from: now)
        if dayISO != today {
            reset(for: today)
        }
    }

    private func ensureDayIsCurrent(using date: Date) {
        let day = Self.isoFormatter.string(from: date)
        if dayISO != day {
            reset(for: day)
        }
    }

    private func save() {
        let today = currentDayISO()
        dayISO = today
        storedDayISO = today

        if let data = try? encoder.encode(entries) {
            storedEntriesJSON = String(decoding: data, as: UTF8.self)
        } else {
            storedEntriesJSON = "[]"
        }
    }

    private func reset(for day: String) {
        entries = []
        dayISO = day
        storedDayISO = day
        storedEntriesJSON = "[]"
    }

    private func currentDayISO() -> String {
        Self.isoFormatter.string(from: Date())
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
