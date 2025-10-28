import Foundation

enum FeatureFlag: String, CaseIterable {
    case logging = "logging"
    case recipes = "recipes"
    case healthKit = "healthKit"
    case wearables = "wearables"
    case ketones = "ketones"
    case dashboardSummary = "dashboard_summary"
    case dashboardTrends = "dashboard_trends"
    case dashboardStreaks = "dashboard_streaks"
    case dashboardMacros = "dashboard_macros"
    case dashboardHydration = "dashboard_hydration"
    case dashboardSleep = "dashboard_sleep"
    case dashboardReadiness = "dashboard_readiness"
    case coach = "coach"
    case quizzes = "quizzes"
    case quizBasics = "quiz_basics"
    case quizLabels = "quiz_labels"
    case quizElectrolytes = "quiz_electrolytes"
    case quizFasting101 = "quiz_fasting101"
    case programme = "programme"
    case challenges = "challenges"
    case challengeElectrolytes7d = "challenge_electrolytes_7d"
    case challengeHydration7d = "challenge_hydration_7d"
    case challengeSteps7d = "challenge_steps_7d"
    case challengeNoSugar7d = "challenge_no_sugar_7d"
    case fasting = "fasting"
}

@propertyWrapper
struct CFFeatureFlag {
    private let flag: FeatureFlag
    private let defaultValue: Bool

    init(key: FeatureFlag, defaultValue: Bool) {
        self.flag = key
        self.defaultValue = defaultValue
        CFFeatureFlags.shared.registerDefault(defaultValue, for: key)
    }

    var wrappedValue: Bool {
        get { CFFeatureFlags.shared.isEnabled(flag) }
        set { CFFeatureFlags.shared.set(flag, enabled: newValue) }
    }
}

final class CFFeatureFlags {
    static let shared = CFFeatureFlags()

    private let defaults: UserDefaults
    private var defaultValues: [FeatureFlag: Bool]
    private let queue = DispatchQueue(label: "com.carbflow.infrastructure.featureflags")

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultValues = Self.defaultFlagValues

        let registeredDefaults = Self.defaultFlagValues.reduce(into: [String: Bool]()) { result, entry in
            result[Self.storageKey(for: entry.key)] = entry.value
        }
        defaults.register(defaults: registeredDefaults)
    }

    private static let defaultFlagValues: [FeatureFlag: Bool] = {
        var values = FeatureFlag.allCases.reduce(into: [FeatureFlag: Bool]()) { result, flag in
            result[flag] = false
        }
        values[.logging] = true
        return values
    }()

    func registerDefault(_ value: Bool, for flag: FeatureFlag) {
        queue.sync {
            defaultValues[flag] = value
        }
    }

    func resetToDefaults() {
        let values = queue.sync { defaultValues }
        for (flag, value) in values {
            set(flag, enabled: value)
        }
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        defaults.bool(forKey: Self.storageKey(for: flag))
    }

    func set(_ flag: FeatureFlag, enabled: Bool) {
        defaults.set(enabled, forKey: Self.storageKey(for: flag))
    }

    private static func storageKey(for flag: FeatureFlag) -> String {
        "cf_\(flag.rawValue)"
    }
}

enum FeatureFlags {
    private enum Keys {
        static let foodLocalStore = "cf_food_local_store"
        static let scanEnabled = "cf_scan_enabled"
    }

    static let foodLocalStoreDidChange = Notification.Name("cf_food_local_store_did_change")
    static let scanDidChange = Notification.Name("cf_scan_enabled_did_change")

    static func configure() {
        _ = CFFeatureFlags.shared
        UserDefaults.standard.register(defaults: [
            Keys.foodLocalStore: true,
            Keys.scanEnabled: true
        ])
    }

    static var foodLocalStoreEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.foodLocalStore)
    }

    static var scanEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.scanEnabled)
    }

    static func setFoodLocalStore(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.foodLocalStore)
        NotificationCenter.default.post(name: foodLocalStoreDidChange, object: nil)
    }

    static func setScanEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.scanEnabled)
        NotificationCenter.default.post(name: scanDidChange, object: nil)
    }
}

// MARK: - CarbFlow-specific Flags

enum CFFlag: String, CaseIterable {
    case cf_fooddb
    case cf_foodsearch
}

enum CFFlags {
    private static let configuration: [String: Bool] = {
        guard let url = locateConfigurationURL(),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any] else {
            return [:]
        }

        return dictionary.reduce(into: [String: Bool]()) { partialResult, entry in
            guard let value = entry.value as? Bool else { return }
            partialResult[entry.key] = value
        }
    }()

    static func isEnabled(_ flag: CFFlag) -> Bool {
        #if DEBUG
        if let override = override(for: flag) {
            return override
        }
        #endif

        if let value = configuration[flag.rawValue] {
            return value
        }

        switch flag {
        case .cf_fooddb:
            return true
        case .cf_foodsearch:
            return true
        }
    }

    #if DEBUG
    static func setOverride(_ flag: CFFlag, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: overrideKey(for: flag))
    }

    static func clearOverride(_ flag: CFFlag) {
        UserDefaults.standard.removeObject(forKey: overrideKey(for: flag))
    }

    static func override(for flag: CFFlag) -> Bool? {
        UserDefaults.standard.object(forKey: overrideKey(for: flag)) as? Bool
    }
    #endif

    private static func locateConfigurationURL() -> URL? {
        let bundleCandidates: [Bundle] = [
            .main,
            Bundle(for: FeatureFlagBundleSentinel.self)
        ]

        for bundle in bundleCandidates {
            if let url = bundle.url(forResource: "FeatureFlags", withExtension: "plist") {
                return url
            }
            if let url = bundle.url(forResource: "FeatureFlags", withExtension: "plist", subdirectory: "Config") {
                return url
            }
            if let url = bundle.url(forResource: "FeatureFlags", withExtension: "plist", subdirectory: "Resources/Config") {
                return url
            }
        }

        return nil
    }

    #if DEBUG
    private static func overrideKey(for flag: CFFlag) -> String {
        "cf_override_\(flag.rawValue)"
    }
    #endif
}

private final class FeatureFlagBundleSentinel {}
