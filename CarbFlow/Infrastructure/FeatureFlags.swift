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
    private let queue = DispatchQueue(label: "com.carbflow.infrastructure.featureflags")
    private var defaultValues: [FeatureFlag: Bool]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultValues = Self.defaultFlagValues

        let registeredDefaults = Self.defaultFlagValues.reduce(into: [String: Bool]()) { result, entry in
            result[Self.storageKey(for: entry.key)] = entry.value
        }
        defaults.register(defaults: registeredDefaults)
    }

    var isLoggingEnabled: Bool {
        get { isEnabled(.logging) }
        set { set(.logging, enabled: newValue) }
    }

    var isRecipesEnabled: Bool {
        get { isEnabled(.recipes) }
        set { set(.recipes, enabled: newValue) }
    }

    var isHealthKitEnabled: Bool {
        get { isEnabled(.healthKit) }
        set { set(.healthKit, enabled: newValue) }
    }

    var isWearablesEnabled: Bool {
        get { isEnabled(.wearables) }
        set { set(.wearables, enabled: newValue) }
    }

    var isKetonesEnabled: Bool {
        get { isEnabled(.ketones) }
        set { set(.ketones, enabled: newValue) }
    }

    var isDashboardSummaryEnabled: Bool {
        get { isEnabled(.dashboardSummary) }
        set { set(.dashboardSummary, enabled: newValue) }
    }

    var isDashboardTrendsEnabled: Bool {
        get { isEnabled(.dashboardTrends) }
        set { set(.dashboardTrends, enabled: newValue) }
    }

    var isDashboardStreaksEnabled: Bool {
        get { isEnabled(.dashboardStreaks) }
        set { set(.dashboardStreaks, enabled: newValue) }
    }

    var isDashboardMacrosEnabled: Bool {
        get { isEnabled(.dashboardMacros) }
        set { set(.dashboardMacros, enabled: newValue) }
    }

    var isDashboardHydrationEnabled: Bool {
        get { isEnabled(.dashboardHydration) }
        set { set(.dashboardHydration, enabled: newValue) }
    }

    var isDashboardSleepEnabled: Bool {
        get { isEnabled(.dashboardSleep) }
        set { set(.dashboardSleep, enabled: newValue) }
    }

    var isDashboardReadinessEnabled: Bool {
        get { isEnabled(.dashboardReadiness) }
        set { set(.dashboardReadiness, enabled: newValue) }
    }

    var isCoachEnabled: Bool {
        get { isEnabled(.coach) }
        set { set(.coach, enabled: newValue) }
    }

    var isQuizzesEnabled: Bool {
        get { isEnabled(.quizzes) }
        set { set(.quizzes, enabled: newValue) }
    }

    var isQuizBasicsEnabled: Bool {
        get { isEnabled(.quizBasics) }
        set { set(.quizBasics, enabled: newValue) }
    }

    var isQuizLabelsEnabled: Bool {
        get { isEnabled(.quizLabels) }
        set { set(.quizLabels, enabled: newValue) }
    }

    var isQuizElectrolytesEnabled: Bool {
        get { isEnabled(.quizElectrolytes) }
        set { set(.quizElectrolytes, enabled: newValue) }
    }

    var isQuizFasting101Enabled: Bool {
        get { isEnabled(.quizFasting101) }
        set { set(.quizFasting101, enabled: newValue) }
    }

    var isProgrammeEnabled: Bool {
        get { isEnabled(.programme) }
        set { set(.programme, enabled: newValue) }
    }

    var isChallengesEnabled: Bool {
        get { isEnabled(.challenges) }
        set { set(.challenges, enabled: newValue) }
    }

    var isChallengeElectrolytes7dEnabled: Bool {
        get { isEnabled(.challengeElectrolytes7d) }
        set { set(.challengeElectrolytes7d, enabled: newValue) }
    }

    var isChallengeHydration7dEnabled: Bool {
        get { isEnabled(.challengeHydration7d) }
        set { set(.challengeHydration7d, enabled: newValue) }
    }

    var isChallengeSteps7dEnabled: Bool {
        get { isEnabled(.challengeSteps7d) }
        set { set(.challengeSteps7d, enabled: newValue) }
    }

    var isChallengeNoSugar7dEnabled: Bool {
        get { isEnabled(.challengeNoSugar7d) }
        set { set(.challengeNoSugar7d, enabled: newValue) }
    }

    var isFastingEnabled: Bool {
        get { isEnabled(.fasting) }
        set { set(.fasting, enabled: newValue) }
    }
    func set(_ flag: FeatureFlag, enabled: Bool) {
        queue.sync {
            defaults.set(enabled, forKey: Self.storageKey(for: flag))
        }
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        queue.sync {
            let key = Self.storageKey(for: flag)
            if defaults.object(forKey: key) == nil {
                return defaultValues[flag] ?? false
            }
            return defaults.bool(forKey: key)
        }
    }

    func resetToDefaults() {
        queue.sync {
            for (flag, value) in defaultValues {
                defaults.set(value, forKey: Self.storageKey(for: flag))
            }
            defaults.synchronize()
        }
    }

    func registerDefault(_ value: Bool, for flag: FeatureFlag) {
        queue.sync {
            defaultValues[flag] = value
            defaults.register(defaults: [Self.storageKey(for: flag): value])
        }
    }

    private static let defaultFlagValues: [FeatureFlag: Bool] = [
        .logging: true,
        .recipes: false,
        .healthKit: false,
        .wearables: false,
        .ketones: false,
        .dashboardSummary: true,
        .dashboardTrends: false,
        .dashboardStreaks: false,
        .dashboardMacros: false,
        .dashboardHydration: false,
        .dashboardSleep: false,
        .dashboardReadiness: false,
        .coach: false,
        .quizzes: false,
        .quizBasics: false,
        .quizLabels: false,
        .quizElectrolytes: false,
        .quizFasting101: false,
        .programme: false,
        .challenges: false,
        .challengeElectrolytes7d: false,
        .challengeHydration7d: false,
        .challengeSteps7d: false,
        .challengeNoSugar7d: false,
        .fasting: false
    ]

    private static func storageKey(for flag: FeatureFlag) -> String {
        "cf_flag_\(flag.rawValue)"
    }
}
