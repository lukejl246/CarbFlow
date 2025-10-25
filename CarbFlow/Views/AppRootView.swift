import SwiftUI

struct AppRootView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false

    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false
    @State private var showWhatsNew = false

    @StateObject private var historyStore: FastingHistoryStore
    @StateObject private var contentStore: ContentStore
    @StateObject private var quizStore: QuizStore
    @StateObject private var listStore: ContentListStore
    @StateObject private var carbStore = CarbIntakeStore()
    @StateObject private var flagStore = FeatureFlagStore()
    @StateObject private var fastingStore: FastingStore
    @StateObject private var whatsNew = WhatsNewStore()

    private static let fastingUnlockDay = 18

    init() {
        let contentStore = ContentStore()
        let historyStore = FastingHistoryStore()
        _contentStore = StateObject(wrappedValue: contentStore)
        _quizStore = StateObject(wrappedValue: QuizStore(contentStore: contentStore))
        _listStore = StateObject(wrappedValue: ContentListStore())
        _historyStore = StateObject(wrappedValue: historyStore)
        _fastingStore = StateObject(wrappedValue: FastingStore(historyStore: historyStore))
    }

    private var learnUnlocked: Bool { currentDay > 1 }
    private var carbTrackerUnlocked: Bool { currentDay > 2 }
    private var timerUnlocked: Bool { currentDay > Self.fastingUnlockDay }

    var body: some View {
        TabView(selection: $selectedTab) {
            learnTab

            if flagStore.loggingEnabled {
                loggingTab
            }

            if flagStore.recipesEnabled {
                recipesTab
            }

            if flagStore.healthKitEnabled {
                healthTab
            }

            if flagStore.wearablesEnabled {
                wearablesTab
            }

            if flagStore.ketonesEnabled {
                ketonesTab
            }

            if flagStore.coachEnabled {
                coachTab
            }

            if flagStore.quizzesEnabled {
                quizzesTab
            }

            if flagStore.programmeEnabled {
                programmeTab
            }

            if flagStore.challengesEnabled {
                challengesTab
            }

            if flagStore.fastingEnabled {
                fastingTab
            }

            carbTrackerTab
            homeTab
            timerTab
        }
        .animation(.easeInOut(duration: 0.25), value: flagStore.loggingEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.recipesEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.healthKitEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.wearablesEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.ketonesEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.coachEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.quizzesEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.programmeEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.challengesEnabled)
        .animation(.easeInOut(duration: 0.25), value: flagStore.fastingEnabled)
        .onAppear {
            if !hasOnboarded {
                showOnboarding = true
            }
            presentWhatsNewIfNeeded()
        }
        .onChange(of: hasOnboarded) { _, newValue in
            if !newValue {
                showOnboarding = true
            }
        }
        .onChange(of: flagStore.loggingEnabled) { _, enabled in
            if !enabled && selectedTab == .logging {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.recipesEnabled) { _, enabled in
            if !enabled && selectedTab == .recipes {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.healthKitEnabled) { _, enabled in
            if !enabled && selectedTab == .health {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.wearablesEnabled) { _, enabled in
            if !enabled && selectedTab == .wearables {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.ketonesEnabled) { _, enabled in
            if !enabled && selectedTab == .ketones {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.coachEnabled) { _, enabled in
            if !enabled && selectedTab == .coach {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.quizzesEnabled) { _, enabled in
            if !enabled && selectedTab == .quizzes {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.programmeEnabled) { _, enabled in
            if !enabled && selectedTab == .programme {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.challengesEnabled) { _, enabled in
            if !enabled && selectedTab == .challenges {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: flagStore.fastingEnabled) { _, enabled in
            if !enabled && selectedTab == .fasting {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .onChange(of: whatsNew.shouldPresent) { _, newValue in
            if newValue {
                presentWhatsNewIfNeeded()
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(contentStore)
                .environmentObject(quizStore)
                .environmentObject(listStore)
                .environmentObject(carbStore)
                .environmentObject(flagStore)
                .environmentObject(historyStore)
                .environmentObject(fastingStore)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(store: whatsNew)
        }
        .environmentObject(contentStore)
        .environmentObject(quizStore)
        .environmentObject(historyStore)
        .environmentObject(fastingStore)
        .environmentObject(listStore)
        .environmentObject(carbStore)
        .environmentObject(flagStore)
    }

    private func presentWhatsNewIfNeeded() {
        guard whatsNew.shouldPresent, !showWhatsNew else { return }
        showWhatsNew = true
        cf_logEvent("whatsnew_show", ["version": whatsNew.payload.versionKey])
    }

    private enum Tab: Hashable {
        case learn
        case logging
        case recipes
        case health
        case wearables
        case ketones
        case coach
        case quizzes
        case programme
        case challenges
        case fasting
        case carbs
        case home
        case timer
    }

    private var learnTab: some View {
        NavigationStack {
            if learnUnlocked {
                LearnView(goToToday: { selectedTab = .home })
            } else {
                LockedPlaceholderView(title: "Learn", message: "Complete Day 1 to unlock")
            }
        }
        .tabItem {
            Label("Learn", systemImage: learnUnlocked ? "book" : "lock.fill")
        }
        .tag(Tab.learn)
    }

    private var loggingTab: some View {
        NavigationStack {
            LoggingDashboard()
                .navigationTitle("Logging")
        }
        .tabItem {
            Label("Logging", systemImage: "waveform.path.ecg")
        }
        .tag(Tab.logging)
    }

    private var recipesTab: some View {
        NavigationStack {
            RecipesDashboard()
                .navigationTitle("Recipes")
        }
        .tabItem {
            Label("Recipes", systemImage: "fork.knife")
        }
        .tag(Tab.recipes)
    }

    private var healthTab: some View {
        NavigationStack {
            HealthDashboard()
                .navigationTitle("Health")
        }
        // TODO(Phase 1): Enable HealthKit capability in Xcode (Signing & Capabilities → + Capability → HealthKit) and add entitlements when implementing reads/writes.
        // Keep the feature flag OFF until permissions + onboarding are implemented.
        .tabItem {
            Label("Health", systemImage: "heart.fill")
        }
        .tag(Tab.health)
    }

    private var wearablesTab: some View {
        NavigationStack {
            WearablesDashboard()
                .navigationTitle("Wearables")
        }
        .tabItem {
            Label("Wearables", systemImage: "applewatch")
        }
        .tag(Tab.wearables)
    }

    private var ketonesTab: some View {
        NavigationStack {
            KetonesDashboard()
                .navigationTitle("Ketones")
        }
        .tabItem {
            Label("Ketones", systemImage: "drop.fill")
        }
        .tag(Tab.ketones)
    }

    private var coachTab: some View {
        NavigationStack {
            CoachDashboard()
                .navigationTitle("Coach")
        }
        .tabItem {
            Label("Coach", systemImage: "person.2.fill")
        }
        .tag(Tab.coach)
    }

    private var quizzesTab: some View {
        NavigationStack {
            QuizzesDashboard()
                .navigationTitle("Quizzes")
        }
        .tabItem {
            Label("Quizzes", systemImage: "questionmark.circle")
        }
        .tag(Tab.quizzes)
    }

    private var programmeTab: some View {
        NavigationStack {
            ProgrammeView()
                .environmentObject(flagStore)
        }
        .tabItem {
            Label("Programme", systemImage: "list.bullet.rectangle")
        }
        .tag(Tab.programme)
    }

    private var challengesTab: some View {
        NavigationStack {
            ChallengesView()
                .environmentObject(flagStore)
        }
        .tabItem {
            Label("Challenges", systemImage: "flag.2.crossed")
        }
        .tag(Tab.challenges)
    }

    private var fastingTab: some View {
        NavigationStack {
            FastingView()
                .environmentObject(flagStore)
        }
        .tabItem {
            Label("Fasting", systemImage: "hourglass.bottomhalf.filled")
        }
        .tag(Tab.fasting)
    }

    private var carbTrackerTab: some View {
        NavigationStack {
            if carbTrackerUnlocked {
                CarbTrackerView()
            } else {
                LockedPlaceholderView(title: "Carbs", message: "Complete Day 2 (Carb Targets) to unlock")
            }
        }
        .tabItem {
            Label("Carbs", systemImage: carbTrackerUnlocked ? "leaf" : "lock.fill")
        }
        .tag(Tab.carbs)
    }

    private var homeTab: some View {
        NavigationStack {
            HomeView()
        }
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(Tab.home)
    }

    private var timerTab: some View {
        NavigationStack {
            if timerUnlocked {
                FastingTimerView()
            } else {
                LockedPlaceholderView(title: "Timer", message: "Complete Day 18 (Meal Timing) to unlock")
            }
        }
        .tabItem {
            Label("Timer", systemImage: timerUnlocked ? "timer" : "lock.fill")
        }
        .tag(Tab.timer)
    }
}

private struct LoggingDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LoggingCard(
                    title: "Event Stream",
                    message: "See real-time events when logging is enabled."
                )
                LoggingCard(
                    title: "Insights",
                    message: "Capture key moments and surface them here once analytics wiring ships."
                )
                LoggingCard(
                    title: "Tips",
                    message: "Use the feature flag to toggle verbose logging when debugging."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct LoggingCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct RecipesDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RecipesCard(
                    title: "Coming Soon",
                    message: "Curated low-carb recipes will appear here once the flag rolls out."
                )
                RecipesCard(
                    title: "Sneak Peek",
                    message: "Expect seasonal menus, prep timelines, and nutrition callouts."
                )
                RecipesCard(
                    title: "Have Ideas?",
                    message: "Share feedback from beta testers to help shape the recipes library."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct RecipesCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct HealthDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HealthCard(
                    title: "HealthKit Sync",
                    message: "Track fasting metrics alongside Apple Health data once HealthKit is enabled."
                )
                HealthCard(
                    title: "Daily Insights",
                    message: "Surface glucose, hydration, and sleep correlations to support smarter carb targets."
                )
                HealthCard(
                    title: "Privacy First",
                    message: "All Health data stays on-device unless you explicitly share summaries."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct HealthCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct WearablesDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WearablesCard(
                    title: "Device Sync",
                    message: "Connect Apple Watch and other wearables to capture heart rate trends for fasting insights."
                )
                // TODO(Phase 1): If on iOS, prefer HealthKit for Apple Watch; request permissions via HKHealthStore. Keep flag OFF until onboarding is ready.
                WearablesCard(
                    title: "Readiness Signals",
                    message: "Leverage wearable metrics to cue recovery-focused carb adjustments."
                )
                // TODO(Phase 2): Consider vendor OAuth integrations (Fitbit, Garmin, Oura). Use ASWebAuthenticationSession for OAuth, store tokens in Keychain, and sync via background tasks.
                // TODO(Phase 2+): Add per-provider sub-flags (fitbit, garmin, oura) under FeatureFlag for staged rollout.
                WearablesCard(
                    title: "Future Integrations",
                    message: "We’re exploring Oura, Whoop, and Garmin support—toggle the flag when ready to test."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct WearablesCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct KetonesDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                KetonesCard(
                    title: "Track Ketone Trends",
                    message: "Log beta-hydroxybutyrate readings to understand your metabolic response." 
                )
                // TODO(Phase 1): Support manual entries for blood b2-HB (mmol/L) and urine/breath qualitative readings. Validate ranges and units.
                // TODO(Phase 1): Add light education micro-copy on safe ranges and testing cadence. [Add refs]
                // TODO(Phase 2): Consider integrating meter imports via HealthKit (if exposed) or CSV import; add per-device sub-flags if needed.
                // Not medical advice.
                KetonesCard(
                    title: "Testing Methods",
                    message: "Compare blood, breath, and urine testing to find the best approach for you." 
                )
                KetonesCard(
                    title: "Nutrition Insights",
                    message: "Use ketone data to refine carb targets and fasting windows for deeper ketosis." 
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct KetonesCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct CoachDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoachCard(
                    title: "Personalised Guidance",
                    message: "Enable the coach feature to receive nudges based on your program progress."
                )
                CoachCard(
                    title: "Habit Focus",
                    message: "We’ll highlight a daily habit to reinforce consistency and accountability."
                )
                CoachCard(
                    title: "Stay Tuned",
                    message: "More coaching modules are in development—flag will unlock when ready."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct CoachCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct QuizzesDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                QuizzesCard(
                    title: "Quiz adventures",
                    message: "Flip this on when quizzes are ready to preview question flow and progress tracking."
                )
                QuizzesCard(
                    title: "Knowledge checks",
                    message: "Expect short, supportive quizzes to reinforce each day’s key takeaways."
                )
                QuizzesCard(
                    title: "Stay tuned",
                    message: "We’ll share results summaries and gentle encouragement once the feature ships."
                )
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

private struct QuizzesCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}
