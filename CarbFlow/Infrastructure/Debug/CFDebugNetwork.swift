import Foundation

enum CFDebugNetwork {
    private static let storageKey = "cf_debug_airplane_mode"

    static let airplaneModeDidChangeNotification = Notification.Name("cf_debug_airplane_mode_did_change")

    static var isAirplaneModeEnabled: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: storageKey)
        #else
        return false
        #endif
    }

    static func setAirplaneModeEnabled(_ enabled: Bool) {
        #if targetEnvironment(simulator)
        UserDefaults.standard.set(enabled, forKey: storageKey)
        NotificationCenter.default.post(name: airplaneModeDidChangeNotification, object: nil)
        #endif
    }
}
