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

    init(flags: CFFeatureFlags) {
        self.flags = flags
        self.loggingEnabled = flags.isLoggingEnabled
        self.recipesEnabled = flags.isRecipesEnabled
        self.healthKitEnabled = flags.isHealthKitEnabled
        self.wearablesEnabled = flags.isWearablesEnabled
        self.ketonesEnabled = flags.isKetonesEnabled
        self.dashboardSummaryEnabled = flags.isDashboardSummaryEnabled
        self.dashboardTrendsEnabled = flags.isDashboardTrendsEnabled
        self.dashboardStreaksEnabled = flags.isDashboardStreaksEnabled
        self.dashboardMacrosEnabled = flags.isDashboardMacrosEnabled
        self.dashboardHydrationEnabled = flags.isDashboardHydrationEnabled
        self.dashboardSleepEnabled = flags.isDashboardSleepEnabled
        self.dashboardReadinessEnabled = flags.isDashboardReadinessEnabled
        self.coachEnabled = flags.isCoachEnabled
        self.quizzesEnabled = flags.isQuizzesEnabled
        self.quizBasicsEnabled = flags.isQuizBasicsEnabled
        self.quizLabelsEnabled = flags.isQuizLabelsEnabled
        self.quizElectrolytesEnabled = flags.isQuizElectrolytesEnabled
        self.quizFasting101Enabled = flags.isQuizFasting101Enabled
        self.programmeEnabled = flags.isProgrammeEnabled
        self.challengesEnabled = flags.isChallengesEnabled
        self.challengeElectrolytes7dEnabled = flags.isChallengeElectrolytes7dEnabled
        self.challengeHydration7dEnabled = flags.isChallengeHydration7dEnabled
        self.challengeSteps7dEnabled = flags.isChallengeSteps7dEnabled
        self.challengeNoSugar7dEnabled = flags.isChallengeNoSugar7dEnabled
        self.fastingEnabled = flags.isFastingEnabled
    }

    convenience init() {
        self.init(flags: CFFeatureFlags.shared)
    }

    func setLogging(_ enabled: Bool) {
        flags.set(.logging, enabled: enabled)
        loggingEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "logging", "enabled": enabled])
    }

    func toggleLogging() {
        setLogging(!loggingEnabled)
    }

    func setRecipes(_ enabled: Bool) {
        flags.set(.recipes, enabled: enabled)
        recipesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "recipes", "enabled": enabled])
    }

    func toggleRecipes() {
        setRecipes(!recipesEnabled)
    }

    func setHealthKit(_ enabled: Bool) {
        flags.set(.healthKit, enabled: enabled)
        healthKitEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "healthKit", "enabled": enabled])
    }

    func toggleHealthKit() {
        setHealthKit(!healthKitEnabled)
    }

    func setWearables(_ enabled: Bool) {
        flags.set(.wearables, enabled: enabled)
        wearablesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "wearables", "enabled": enabled])
    }

    func toggleWearables() {
        setWearables(!wearablesEnabled)
    }

    func setKetones(_ enabled: Bool) {
        flags.set(.ketones, enabled: enabled)
        ketonesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "ketones", "enabled": enabled])
    }

    func toggleKetones() {
        setKetones(!ketonesEnabled)
    }

    func setDashboardSummary(_ enabled: Bool) {
        flags.set(.dashboardSummary, enabled: enabled)
        dashboardSummaryEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardSummary", "enabled": enabled])
    }

    func toggleDashboardSummary() {
        setDashboardSummary(!dashboardSummaryEnabled)
    }

    func setDashboardTrends(_ enabled: Bool) {
        flags.set(.dashboardTrends, enabled: enabled)
        dashboardTrendsEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardTrends", "enabled": enabled])
    }

    func toggleDashboardTrends() {
        setDashboardTrends(!dashboardTrendsEnabled)
    }

    func setDashboardStreaks(_ enabled: Bool) {
        flags.set(.dashboardStreaks, enabled: enabled)
        dashboardStreaksEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardStreaks", "enabled": enabled])
    }

    func toggleDashboardStreaks() {
        setDashboardStreaks(!dashboardStreaksEnabled)
    }

    func setDashboardMacros(_ enabled: Bool) {
        flags.set(.dashboardMacros, enabled: enabled)
        dashboardMacrosEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardMacros", "enabled": enabled])
    }

    func toggleDashboardMacros() {
        setDashboardMacros(!dashboardMacrosEnabled)
    }

    func setDashboardHydration(_ enabled: Bool) {
        flags.set(.dashboardHydration, enabled: enabled)
        dashboardHydrationEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardHydration", "enabled": enabled])
    }

    func toggleDashboardHydration() {
        setDashboardHydration(!dashboardHydrationEnabled)
    }

    func setDashboardSleep(_ enabled: Bool) {
        flags.set(.dashboardSleep, enabled: enabled)
        dashboardSleepEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardSleep", "enabled": enabled])
    }

    func toggleDashboardSleep() {
        setDashboardSleep(!dashboardSleepEnabled)
    }

    func setDashboardReadiness(_ enabled: Bool) {
        flags.set(.dashboardReadiness, enabled: enabled)
        dashboardReadinessEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "dashboardReadiness", "enabled": enabled])
    }

    func toggleDashboardReadiness() {
        setDashboardReadiness(!dashboardReadinessEnabled)
    }

    func setCoach(_ enabled: Bool) {
        flags.set(.coach, enabled: enabled)
        coachEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "coach", "enabled": enabled])
    }

    func toggleCoach() {
        setCoach(!coachEnabled)
    }

    func setQuizzes(_ enabled: Bool) {
        flags.set(.quizzes, enabled: enabled)
        quizzesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "quizzes", "enabled": enabled])
    }

    func toggleQuizzes() {
        setQuizzes(!quizzesEnabled)
    }

    func setQuizBasics(_ enabled: Bool) {
        flags.set(.quizBasics, enabled: enabled)
        quizBasicsEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "quizBasics", "enabled": enabled])
    }

    func toggleQuizBasics() {
        setQuizBasics(!quizBasicsEnabled)
    }

    func setQuizLabels(_ enabled: Bool) {
        flags.set(.quizLabels, enabled: enabled)
        quizLabelsEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "quizLabels", "enabled": enabled])
    }

    func toggleQuizLabels() {
        setQuizLabels(!quizLabelsEnabled)
    }

    func setQuizElectrolytes(_ enabled: Bool) {
        flags.set(.quizElectrolytes, enabled: enabled)
        quizElectrolytesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "quizElectrolytes", "enabled": enabled])
    }

    func toggleQuizElectrolytes() {
        setQuizElectrolytes(!quizElectrolytesEnabled)
    }

    func setQuizFasting101(_ enabled: Bool) {
        flags.set(.quizFasting101, enabled: enabled)
        quizFasting101Enabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "quizFasting101", "enabled": enabled])
    }

    func toggleQuizFasting101() {
        setQuizFasting101(!quizFasting101Enabled)
    }

    func setProgramme(_ enabled: Bool) {
        flags.set(.programme, enabled: enabled)
        programmeEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "programme", "enabled": enabled])
    }

    func toggleProgramme() {
        setProgramme(!programmeEnabled)
    }

    func setChallenges(_ enabled: Bool) {
        flags.set(.challenges, enabled: enabled)
        challengesEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "challenges", "enabled": enabled])
    }

    func toggleChallenges() {
        setChallenges(!challengesEnabled)
    }

    func setChallengeElectrolytes7d(_ enabled: Bool) {
        flags.set(.challengeElectrolytes7d, enabled: enabled)
        challengeElectrolytes7dEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "challengeElectrolytes7d", "enabled": enabled])
    }

    func toggleChallengeElectrolytes7d() {
        setChallengeElectrolytes7d(!challengeElectrolytes7dEnabled)
    }

    func setChallengeHydration7d(_ enabled: Bool) {
        flags.set(.challengeHydration7d, enabled: enabled)
        challengeHydration7dEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "challengeHydration7d", "enabled": enabled])
    }

    func toggleChallengeHydration7d() {
        setChallengeHydration7d(!challengeHydration7dEnabled)
    }

    func setChallengeSteps7d(_ enabled: Bool) {
        flags.set(.challengeSteps7d, enabled: enabled)
        challengeSteps7dEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "challengeSteps7d", "enabled": enabled])
    }

    func toggleChallengeSteps7d() {
        setChallengeSteps7d(!challengeSteps7dEnabled)
    }

    func setChallengeNoSugar7d(_ enabled: Bool) {
        flags.set(.challengeNoSugar7d, enabled: enabled)
        challengeNoSugar7dEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "challengeNoSugar7d", "enabled": enabled])
    }

    func toggleChallengeNoSugar7d() {
        setChallengeNoSugar7d(!challengeNoSugar7dEnabled)
    }

    func setFasting(_ enabled: Bool) {
        flags.set(.fasting, enabled: enabled)
        fastingEnabled = enabled
        cf_logEvent("feature_flag_toggled", ["flag": "fasting", "enabled": enabled])
    }

    func toggleFasting() {
        setFasting(!fastingEnabled)
    }

    private let flags: CFFeatureFlags
}
