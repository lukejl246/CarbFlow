import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var contentStore: ContentStore
    @EnvironmentObject private var flagStore: FeatureFlagStore
    @AppStorage(Keys.currentDay) private var storedCurrentDay = 1
    @AppStorage(Keys.streakCount) private var storedStreak = 0
    @AppStorage(Keys.lastCompletionISO) private var storedLastISO = ""
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @AppStorage("cf_quizCorrectDays") private var quizCorrectDaysStorage: String = "[]"

    @State private var selectedDay = 1
    @State private var showResetAlert = false
#if DEBUG
    @State private var showWhatsNewSheet = false
    @State private var whatsNewStore = WhatsNewStore()
    @State private var analyticsEnabled = AnalyticsRouter.enabled
    @State private var errorReportingEnabled = CFErrorReportingRouter.shared.enabled
    @State private var foodLocalStoreEnabled = FeatureFlags.foodLocalStoreEnabled
    @State private var foodDatabaseEnabled = CFFlags.isEnabled(.cf_fooddb)
    @State private var airplaneModeEnabled = CFDebugNetwork.isAirplaneModeEnabled
    @State private var predictiveSearchEnabled = CFFlags.isEnabled(.cf_foodsearch)
#endif

    private var totalDays: Int {
        max(contentStore.totalDays, 1)
    }

    var body: some View {
        List {
            Section("General") {
                Label("About", systemImage: "info.circle")
                Label("Disclaimer", systemImage: "exclamationmark.triangle")
                Label("Support", systemImage: "envelope")
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
                NavigationLink {
                    HelpCardView()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            }

            Section("Progress Controls") {
                Stepper(value: $selectedDay, in: 1...totalDays) {
                    Text("Jump to Day \(selectedDay)")
                }

                Text("Current app day: \(storedCurrentDay)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Apply Day") {
                    applySelectedDay()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Developer Tools") {
#if DEBUG
                analyticsToggleCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                errorReportingToggleCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                featureFlagToggle
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                foodDatabaseToggle
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                #if targetEnvironment(simulator)
                airplaneModeToggle
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                #endif
                predictiveSearchToggle
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                Button("Show What's New") {
                    presentWhatsNew()
                }
                .buttonStyle(.bordered)

                NavigationLink("Feature Flags") {
                    DevFlagsView()
                        .environmentObject(flagStore)
                }
                if CFFlags.isEnabled(.cf_fooddb) {
                    NavigationLink("Food Seed Smoke Test") {
                        SearchSeedSmokeTestViewContainer()
                    }
                }
#endif

                Button("Reset Progress", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .onAppear {
            syncSelectedDay()
#if DEBUG
            analyticsEnabled = AnalyticsRouter.enabled
            foodDatabaseEnabled = CFFlags.isEnabled(.cf_fooddb)
            #if targetEnvironment(simulator)
            airplaneModeEnabled = CFDebugNetwork.isAirplaneModeEnabled
            #endif
            predictiveSearchEnabled = CFFlags.isEnabled(.cf_foodsearch)
#endif
        }
        .onChange(of: storedCurrentDay) { _, _ in
            syncSelectedDay()
        }
#if DEBUG
        .onChange(of: analyticsEnabled) { _, newValue in
            AnalyticsRouter.enabled = newValue
        }
        .onChange(of: errorReportingEnabled) { _, newValue in
            CFErrorReportingRouter.shared.enabled = newValue
        }
        .onChange(of: foodLocalStoreEnabled) { _, newValue in
            FeatureFlags.setFoodLocalStore(enabled: newValue)
        }
        .onChange(of: foodDatabaseEnabled) { _, newValue in
            CFFlags.setOverride(.cf_fooddb, enabled: newValue)
        }
        #if targetEnvironment(simulator)
        .onChange(of: airplaneModeEnabled) { _, newValue in
            CFDebugNetwork.setAirplaneModeEnabled(newValue)
        }
        #endif
        .onChange(of: predictiveSearchEnabled) { _, newValue in
            CFFlags.setOverride(.cf_foodsearch, enabled: newValue)
            cf_logEvent("FoodSearchFlagToggled", ["enabled": newValue])
        }
#endif
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This clears streaks and daily progress so you can restart.")
        }
#if DEBUG
        .sheet(isPresented: $showWhatsNewSheet) {
            WhatsNewView(store: whatsNewStore)
        }
#endif
    }

    private func syncSelectedDay() {
        selectedDay = min(max(storedCurrentDay, 1), totalDays)
    }

    private func applySelectedDay() {
        let clamped = min(max(selectedDay, 1), totalDays)
        selectedDay = clamped
        storedCurrentDay = clamped
        storedStreak = max(clamped - 1, 0)
        storedLastISO = ""
    }

    private func resetProgress() {
        storedCurrentDay = 1
        storedStreak = 0
        storedLastISO = ""
        hasOnboarded = false
        quizCorrectDaysStorage = "[]"
        selectedDay = 1
    }

#if DEBUG
    private func presentWhatsNew() {
        UserDefaults.standard.removeObject(forKey: CFKeys.whatsNewLastSeen)
        whatsNewStore = WhatsNewStore()
        showWhatsNewSheet = true
    }

    private var analyticsToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Analytics (console)", isOn: $analyticsEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var errorReportingToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Error reporting (console)", isOn: $errorReportingEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var featureFlagToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Local food store", isOn: $foodLocalStoreEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var foodDatabaseToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Food database + seeding", isOn: $foodDatabaseEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    #if targetEnvironment(simulator)
    private var airplaneModeToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Simulate airplane mode", isOn: $airplaneModeEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
            Text("Disable simulated network connectivity while running in the simulator.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
    #endif

    private var predictiveSearchToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Predictive food search", isOn: $predictiveSearchEnabled)
                .tint(.accentColor)
                .frame(minHeight: 44)
            Text("Toggle between predictive and basic prefix search to compare behaviour.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    @MainActor
    private struct SearchSeedSmokeTestViewContainer: View {
        var body: some View {
            SearchSeedSmokeTestView.makeDefault()
        }
    }
#endif
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ContentStore())
            .environmentObject(FeatureFlagStore())
    }
}
