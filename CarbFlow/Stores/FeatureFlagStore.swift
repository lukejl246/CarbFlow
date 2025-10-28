import Combine

@MainActor
final class FeatureFlagStore: ObservableObject {
    @Published var loggingEnabled: Bool
    @Published var recipesEnabled: Bool
    @Published var healthKitEnabled: Bool
    @Published var wearablesEnabled: Bool
    @Published var ketonesEnabled: Bool
    @Published var dashboardSummaryEnabled: Bool
    @Published var dashboardTrendsEnabled: Bool
    @Published var dashboardStreaksEnabled: Bool
    @Published var dashboardMacrosEnabled: Bool
    @Published var dashboardHydrationEnabled: Bool
    @Published var dashboardSleepEnabled: Bool
    @Published var dashboardReadinessEnabled: Bool
    @Published var coachEnabled: Bool
    @Published var quizzesEnabled: Bool
    @Published var quizBasicsEnabled: Bool
    @Published var quizLabelsEnabled: Bool
    @Published var quizElectrolytesEnabled: Bool
    @Published var quizFasting101Enabled: Bool
    @Published var programmeEnabled: Bool
    @Published var challengesEnabled: Bool
    @Published var challengeElectrolytes7dEnabled: Bool
    @Published var challengeHydration7dEnabled: Bool
    @Published var challengeSteps7dEnabled: Bool
    @Published var challengeNoSugar7dEnabled: Bool
    @Published var fastingEnabled: Bool

    private let flags: CFFeatureFlags

    init(flags: CFFeatureFlags? = nil) {
        let resolvedFlags = flags ?? CFFeatureFlags.shared
        self.flags = resolvedFlags
        self.loggingEnabled = resolvedFlags.isEnabled(.logging)
        self.recipesEnabled = resolvedFlags.isEnabled(.recipes)
        self.healthKitEnabled = resolvedFlags.isEnabled(.healthKit)
        self.wearablesEnabled = resolvedFlags.isEnabled(.wearables)
        self.ketonesEnabled = resolvedFlags.isEnabled(.ketones)
        self.dashboardSummaryEnabled = resolvedFlags.isEnabled(.dashboardSummary)
        self.dashboardTrendsEnabled = resolvedFlags.isEnabled(.dashboardTrends)
        self.dashboardStreaksEnabled = resolvedFlags.isEnabled(.dashboardStreaks)
        self.dashboardMacrosEnabled = resolvedFlags.isEnabled(.dashboardMacros)
        self.dashboardHydrationEnabled = resolvedFlags.isEnabled(.dashboardHydration)
        self.dashboardSleepEnabled = resolvedFlags.isEnabled(.dashboardSleep)
        self.dashboardReadinessEnabled = resolvedFlags.isEnabled(.dashboardReadiness)
        self.coachEnabled = resolvedFlags.isEnabled(.coach)
        self.quizzesEnabled = resolvedFlags.isEnabled(.quizzes)
        self.quizBasicsEnabled = resolvedFlags.isEnabled(.quizBasics)
        self.quizLabelsEnabled = resolvedFlags.isEnabled(.quizLabels)
        self.quizElectrolytesEnabled = resolvedFlags.isEnabled(.quizElectrolytes)
        self.quizFasting101Enabled = resolvedFlags.isEnabled(.quizFasting101)
        self.programmeEnabled = resolvedFlags.isEnabled(.programme)
        self.challengesEnabled = resolvedFlags.isEnabled(.challenges)
        self.challengeElectrolytes7dEnabled = resolvedFlags.isEnabled(.challengeElectrolytes7d)
        self.challengeHydration7dEnabled = resolvedFlags.isEnabled(.challengeHydration7d)
        self.challengeSteps7dEnabled = resolvedFlags.isEnabled(.challengeSteps7d)
        self.challengeNoSugar7dEnabled = resolvedFlags.isEnabled(.challengeNoSugar7d)
        self.fastingEnabled = resolvedFlags.isEnabled(.fasting)
    }

    func resetToDefaults() {
        flags.resetToDefaults()
        loggingEnabled = flags.isEnabled(.logging)
        recipesEnabled = flags.isEnabled(.recipes)
        healthKitEnabled = flags.isEnabled(.healthKit)
        wearablesEnabled = flags.isEnabled(.wearables)
        ketonesEnabled = flags.isEnabled(.ketones)
        dashboardSummaryEnabled = flags.isEnabled(.dashboardSummary)
        dashboardTrendsEnabled = flags.isEnabled(.dashboardTrends)
        dashboardStreaksEnabled = flags.isEnabled(.dashboardStreaks)
        dashboardMacrosEnabled = flags.isEnabled(.dashboardMacros)
        dashboardHydrationEnabled = flags.isEnabled(.dashboardHydration)
        dashboardSleepEnabled = flags.isEnabled(.dashboardSleep)
        dashboardReadinessEnabled = flags.isEnabled(.dashboardReadiness)
        coachEnabled = flags.isEnabled(.coach)
        quizzesEnabled = flags.isEnabled(.quizzes)
        quizBasicsEnabled = flags.isEnabled(.quizBasics)
        quizLabelsEnabled = flags.isEnabled(.quizLabels)
        quizElectrolytesEnabled = flags.isEnabled(.quizElectrolytes)
        quizFasting101Enabled = flags.isEnabled(.quizFasting101)
        programmeEnabled = flags.isEnabled(.programme)
        challengesEnabled = flags.isEnabled(.challenges)
        challengeElectrolytes7dEnabled = flags.isEnabled(.challengeElectrolytes7d)
        challengeHydration7dEnabled = flags.isEnabled(.challengeHydration7d)
        challengeSteps7dEnabled = flags.isEnabled(.challengeSteps7d)
        challengeNoSugar7dEnabled = flags.isEnabled(.challengeNoSugar7d)
        fastingEnabled = flags.isEnabled(.fasting)
    }

    func set(_ flag: FeatureFlag, enabled: Bool) {
        flags.set(flag, enabled: enabled)
        switch flag {
        case .logging: loggingEnabled = enabled
        case .recipes: recipesEnabled = enabled
        case .healthKit: healthKitEnabled = enabled
        case .wearables: wearablesEnabled = enabled
        case .ketones: ketonesEnabled = enabled
        case .dashboardSummary: dashboardSummaryEnabled = enabled
        case .dashboardTrends: dashboardTrendsEnabled = enabled
        case .dashboardStreaks: dashboardStreaksEnabled = enabled
        case .dashboardMacros: dashboardMacrosEnabled = enabled
        case .dashboardHydration: dashboardHydrationEnabled = enabled
        case .dashboardSleep: dashboardSleepEnabled = enabled
        case .dashboardReadiness: dashboardReadinessEnabled = enabled
        case .coach: coachEnabled = enabled
        case .quizzes: quizzesEnabled = enabled
        case .quizBasics: quizBasicsEnabled = enabled
        case .quizLabels: quizLabelsEnabled = enabled
        case .quizElectrolytes: quizElectrolytesEnabled = enabled
        case .quizFasting101: quizFasting101Enabled = enabled
        case .programme: programmeEnabled = enabled
        case .challenges: challengesEnabled = enabled
        case .challengeElectrolytes7d: challengeElectrolytes7dEnabled = enabled
        case .challengeHydration7d: challengeHydration7dEnabled = enabled
        case .challengeSteps7d: challengeSteps7dEnabled = enabled
        case .challengeNoSugar7d: challengeNoSugar7dEnabled = enabled
        case .fasting: fastingEnabled = enabled
        }
    }
}
