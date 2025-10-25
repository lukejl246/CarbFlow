import Combine
import Foundation

@MainActor
final class FastingStore: ObservableObject {
    @Published private(set) var isFasting: Bool
    @Published private(set) var startDate: Date?

    private let historyStore: FastingHistoryStore
    private let userDefaults: UserDefaults
    private let now: () -> Date

    init(historyStore: FastingHistoryStore,
         userDefaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init) {
        self.historyStore = historyStore
        self.userDefaults = userDefaults
        self.now = now

        let storedStart = userDefaults.double(forKey: Keys.fastingStart)
        let storedActive = userDefaults.bool(forKey: Keys.isFasting)
        if storedActive, storedStart > 0 {
            self.isFasting = true
            self.startDate = Date(timeIntervalSince1970: storedStart)
        } else {
            self.isFasting = false
            self.startDate = nil
        }
    }

    func elapsed(at date: Date) -> TimeInterval {
        guard isFasting, let startDate else { return 0 }
        return date.timeIntervalSince(startDate)
    }

    @discardableResult
    func startFast(protocolName: String? = nil) -> Bool {
        var breadcrumbData: [String: Any]? = nil
        if let protocolName, !protocolName.isEmpty {
            breadcrumbData = ["protocol": protocolName]
        }
        cf_breadcrumbAction("fast_start_tap", data: breadcrumbData)

        guard !isFasting else {
            cf_reportWarning(message: "fast_start_invalid", context: ["reason": "already_active_fast"])
            return false
        }

        let start = now()
        let timestamp = start.timeIntervalSince1970
        userDefaults.set(timestamp, forKey: Keys.fastingStart)
        userDefaults.set(true, forKey: Keys.isFasting)

        let persistedTimestamp = userDefaults.double(forKey: Keys.fastingStart)
        let persistedFlag = userDefaults.bool(forKey: Keys.isFasting)
        guard persistedFlag, persistedTimestamp > 0 else {
            var context: [String: Any] = [:]
            if let protocolName, !protocolName.isEmpty {
                context["protocol"] = protocolName
            }
            cf_reportError(message: "fast_start_failed", code: "persist_failed", context: context)
            userDefaults.set(0, forKey: Keys.fastingStart)
            userDefaults.set(false, forKey: Keys.isFasting)
            return false
        }

        isFasting = true
        startDate = Date(timeIntervalSince1970: persistedTimestamp)
        logFastStarted(protocolName: protocolName)
        return true
    }

    @discardableResult
    func stopFast() -> Bool {
        cf_breadcrumbAction("fast_stop_tap")

        guard isFasting, let startDate else {
            cf_reportWarning(message: "fast_stop_invalid", context: ["reason": "no_active_fast"])
            return false
        }

        let endDate = now()
        let durationSeconds = max(Int(endDate.timeIntervalSince(startDate)), 0)

        let previousCount = historyStore.sessions.count
        historyStore.append(start: startDate, end: endDate)
        let didAppend = historyStore.sessions.count > previousCount

        userDefaults.set(0, forKey: Keys.fastingStart)
        userDefaults.set(false, forKey: Keys.isFasting)

        let persistedFlag = userDefaults.bool(forKey: Keys.isFasting)
        let persistedTimestamp = userDefaults.double(forKey: Keys.fastingStart)

        isFasting = false
        self.startDate = nil

        if !didAppend {
            cf_reportError(
                message: "fast_stop_failed",
                code: "history_append_failed",
                context: ["elapsed_s": durationSeconds]
            )
        } else if persistedFlag || persistedTimestamp != 0 {
            cf_reportError(
                message: "fast_stop_failed",
                code: "persist_clearing_failed",
                context: ["elapsed_s": durationSeconds]
            )
        }

        logFastStopped(durationSeconds: durationSeconds)
        return didAppend && !persistedFlag && persistedTimestamp == 0
    }
}
