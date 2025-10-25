import Foundation
@preconcurrency import Combine

struct FastingSession: Identifiable, Codable, Equatable {
    let id: UUID
    let start: Date
    let end: Date
    let durationSeconds: Int

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
        self.durationSeconds = Int(end.timeIntervalSince(start))
    }
}

@MainActor
final class FastingHistoryStore: ObservableObject {
    @Published private(set) var sessions: [FastingSession] = []

    private let url: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(filename: String = "fasting_history.json") {
        self.url = Self.documentsDirectory.appendingPathComponent(filename)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    func append(start: Date, end: Date) {
        guard end >= start else { return }
        let session = FastingSession(start: start, end: end)
        sessions.append(session)
        sessions.sort(by: { $0.start > $1.start })
        save()
    }

    func remove(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions.remove(at: index)
            save()
        }
    }

    func removeAll() {
        guard !sessions.isEmpty else { return }
        sessions.removeAll()
        save()
    }

    func totalDuration(hoursWithin days: Int) -> Double {
        guard days > 0 else { return 0 }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        let totalSeconds = sessions
            .filter { $0.end >= cutoff }
            .reduce(0) { $0 + $1.durationSeconds }
        return Double(totalSeconds) / 3600.0
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            sessions = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([FastingSession].self, from: data)
            sessions = decoded.sorted(by: { $0.start > $1.start })
        } catch {
            print("[FastingHistoryStore] Failed to load history: \(error)")
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(sessions)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("[FastingHistoryStore] Failed to save history: \(error)")
        }
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
