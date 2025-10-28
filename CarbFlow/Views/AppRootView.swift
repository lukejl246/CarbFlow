import SwiftUI

struct AppRootView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false

    @State private var showOnboarding = false
    @State private var showWhatsNew = false
    @State private var selectedTab: Tab = FeatureFlags.foodLocalStoreEnabled ? .logging : .home
    @State private var foodLocalEnabled = FeatureFlags.foodLocalStoreEnabled

    @StateObject private var contentStore = ContentStore()
    @StateObject private var flagStore = FeatureFlagStore()
    @StateObject private var whatsNew = WhatsNewStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            if flagStore.loggingEnabled { loggingTab }
            if flagStore.recipesEnabled { recipesTab }
            if flagStore.healthKitEnabled { healthTab }
            if flagStore.wearablesEnabled { wearablesTab }
            if flagStore.ketonesEnabled { ketonesTab }
            if flagStore.coachEnabled { coachTab }
            if flagStore.quizzesEnabled { quizzesTab }
            if flagStore.programmeEnabled { programmeTab }
            if flagStore.challengesEnabled { challengesTab }
            if flagStore.fastingEnabled { fastingTab }
            homeTab
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
        .animation(.easeInOut(duration: 0.25), value: foodLocalEnabled)
        .onAppear {
            if !flagStore.loggingEnabled {
                guardDisableTab(.logging, enabled: false)
            }
            if !hasOnboarded { showOnboarding = true }
            presentWhatsNewIfNeeded()
        }
        .onChange(of: hasOnboarded) { _, newValue in
            if !newValue { showOnboarding = true }
        }
        .onChange(of: flagStore.loggingEnabled) { _, enabled in guardDisableTab(.logging, enabled: enabled) }
        .onChange(of: flagStore.recipesEnabled) { _, enabled in guardDisableTab(.recipes, enabled: enabled) }
        .onChange(of: flagStore.healthKitEnabled) { _, enabled in guardDisableTab(.health, enabled: enabled) }
        .onChange(of: flagStore.wearablesEnabled) { _, enabled in guardDisableTab(.wearables, enabled: enabled) }
        .onChange(of: flagStore.ketonesEnabled) { _, enabled in guardDisableTab(.ketones, enabled: enabled) }
        .onChange(of: flagStore.coachEnabled) { _, enabled in guardDisableTab(.coach, enabled: enabled) }
        .onChange(of: flagStore.quizzesEnabled) { _, enabled in guardDisableTab(.quizzes, enabled: enabled) }
        .onChange(of: flagStore.programmeEnabled) { _, enabled in guardDisableTab(.programme, enabled: enabled) }
        .onChange(of: flagStore.challengesEnabled) { _, enabled in guardDisableTab(.challenges, enabled: enabled) }
        .onChange(of: flagStore.fastingEnabled) { _, enabled in guardDisableTab(.fasting, enabled: enabled) }
        .onReceive(NotificationCenter.default.publisher(for: FeatureFlags.foodLocalStoreDidChange)) { _ in
            let enabled = FeatureFlags.foodLocalStoreEnabled
            if !enabled && selectedTab == .logging {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                foodLocalEnabled = enabled
            }
        }
        .onChange(of: whatsNew.shouldPresent) { _, newValue in
            if newValue { presentWhatsNewIfNeeded() }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(store: whatsNew)
        }
        .environmentObject(contentStore)
        .environmentObject(flagStore)
    }

    private func guardDisableTab(_ tab: Tab, enabled: Bool) {
        if !enabled && selectedTab == tab {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .home
            }
        }
    }

    private func presentWhatsNewIfNeeded() {
        guard whatsNew.shouldPresent, !showWhatsNew else { return }
        showWhatsNew = true
        cf_logEvent("whatsnew_show", ["version": whatsNew.payload.versionKey])
    }

    private enum Tab: Hashable {
        case logging, recipes, health, wearables, ketones
        case coach, quizzes, programme, challenges, fasting
        case home
    }

    private func placeholder(title: String, message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 80)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var loggingTab: some View {
        NavigationStack {
            if foodLocalEnabled {
                LogView()
            } else {
                placeholder(
                    title: "Logging",
                    message: "Enable the local food store flag to browse foods and begin logging."
                )
            }
        }
        .tabItem { Label("Logging", systemImage: "waveform.path.ecg") }
        .tag(Tab.logging)
    }

    private var recipesTab: some View {
        NavigationStack { placeholder(title: "Recipes", message: "Recipe discovery is in progress. Toggle the flag to preview when available.") }
            .tabItem { Label("Recipes", systemImage: "fork.knife") }
            .tag(Tab.recipes)
    }

    private var healthTab: some View {
        NavigationStack { placeholder(title: "Health", message: "Health integrations will land here after permissions and onboarding are ready.") }
            .tabItem { Label("Health", systemImage: "heart.fill") }
            .tag(Tab.health)
    }

    private var wearablesTab: some View {
        NavigationStack { placeholder(title: "Wearables", message: "Connect wearables soon to surface your sensor trends.") }
            .tabItem { Label("Wearables", systemImage: "applewatch") }
            .tag(Tab.wearables)
    }

    private var ketonesTab: some View {
        NavigationStack { placeholder(title: "Ketones", message: "Ketone tracking dashboards will appear once data integrations are complete.") }
            .tabItem { Label("Ketones", systemImage: "drop.fill") }
            .tag(Tab.ketones)
    }

    private var coachTab: some View {
        NavigationStack { placeholder(title: "Coach", message: "Personalised coaching nudges will arrive later in the roadmap.") }
            .tabItem { Label("Coach", systemImage: "person.2.fill") }
            .tag(Tab.coach)
    }

    private var quizzesTab: some View {
        NavigationStack { placeholder(title: "Quizzes", message: "Knowledge checks are coming soon. Enable to preview copy when ready.") }
            .tabItem { Label("Quizzes", systemImage: "questionmark.circle") }
            .tag(Tab.quizzes)
    }

    private var programmeTab: some View {
        NavigationStack { placeholder(title: "Programme", message: "Long-form programmes will live here when they’re ready.") }
            .tabItem { Label("Programme", systemImage: "list.bullet.rectangle") }
            .tag(Tab.programme)
    }

    private var challengesTab: some View {
        NavigationStack { placeholder(title: "Challenges", message: "Sprint-style challenges will unlock in this space later.") }
            .tabItem { Label("Challenges", systemImage: "flag.2.crossed") }
            .tag(Tab.challenges)
    }

    private var fastingTab: some View {
        NavigationStack { placeholder(title: "Fasting", message: "Fasting timers and history will return after the next milestone.") }
            .tabItem { Label("Fasting", systemImage: "hourglass") }
            .tag(Tab.fasting)
    }

    private var homeTab: some View {
        NavigationStack { HomeView() }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)
    }
}
