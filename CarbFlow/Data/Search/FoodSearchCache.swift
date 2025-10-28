import Foundation

struct CachedSearchEntry: Codable {
    let query: String
    let ids: [UUID]
}

final class FoodSearchCache {
    static let shared = FoodSearchCache()

    private let storeKey = "cf_food_search_cache"
    private let userDefaults: UserDefaults
    private let queue = DispatchQueue(label: "com.carbflow.foodsearchcache", qos: .utility)
    private let maxEntries = 20

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(query: String, ids: [UUID], seedVersion: Int64) {
        guard !ids.isEmpty else { return }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        queue.async {
            var payload = self.loadPayload()
            if payload.version != seedVersion {
                payload = CachePayload(version: seedVersion, entries: [])
            }

            let newEntry = CachedSearchEntry(query: trimmedQuery.lowercased(), ids: ids)
            var entries = payload.entries.filter { $0.query != newEntry.query }
            entries.insert(newEntry, at: 0)
            if entries.count > self.maxEntries {
                entries = Array(entries.prefix(self.maxEntries))
            }

            payload.entries = entries
            self.savePayload(payload)
        }
    }

    func get(query: String, seedVersion: Int64) -> [UUID]? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else { return nil }

        return queue.sync {
            let payload = self.loadPayload()
            guard payload.version == seedVersion else {
                return nil
            }
            return payload.entries.first(where: { $0.query == trimmedQuery })?.ids
        }
    }

    func clear() {
        queue.async {
            self.userDefaults.removeObject(forKey: self.storeKey)
        }
    }

    // MARK: - Storage

    private struct CachePayload: Codable {
        var version: Int64
        var entries: [CachedSearchEntry]
    }

    private func loadPayload() -> CachePayload {
        guard let data = userDefaults.data(forKey: storeKey) else {
            return CachePayload(version: 0, entries: [])
        }
        do {
            return try JSONDecoder().decode(CachePayload.self, from: data)
        } catch {
            return CachePayload(version: 0, entries: [])
        }
    }

    private func savePayload(_ payload: CachePayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            userDefaults.set(data, forKey: storeKey)
        } catch {
            #if DEBUG
            print("[FoodSearchCache] Failed to save payload: \(error)")
            #endif
        }
    }

    private func pruneIfNeeded() { }
}
