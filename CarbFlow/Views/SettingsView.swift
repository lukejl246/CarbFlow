import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var contentStore: ContentStore
    @EnvironmentObject private var flagStore: FeatureFlagStore
    @AppStorage(Keys.currentDay) private var storedCurrentDay = 1
    @AppStorage(Keys.streakCount) private var storedStreak = 0
    @AppStorage(Keys.lastCompletionISO) private var storedLastISO = ""
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(Keys.carbTarget) private var storedCarbTarget = 0
    @AppStorage(Keys.hasSetCarbTarget) private var hasSetCarbTarget = false
    @AppStorage("cf_quizCorrectDays") private var quizCorrectDaysStorage: String = "[]"

    @State private var selectedDay = 1
    @State private var showResetAlert = false
#if DEBUG
    @State private var showWhatsNewSheet = false
    @State private var whatsNewStore = WhatsNewStore()
    @State private var analyticsEnabled = AnalyticsRouter.enabled
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
#endif
                Button("Show Onboarding") {
                    hasOnboarded = false
                }
                .buttonStyle(.bordered)

#if DEBUG
                Button("Show What's New") {
                    presentWhatsNew()
                }
                .buttonStyle(.bordered)

                NavigationLink("Feature Flags") {
                    DevFlagsView()
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
#endif
        }
        .onChange(of: storedCurrentDay) { _ in
            syncSelectedDay()
        }
#if DEBUG
        .onChange(of: analyticsEnabled) { _, newValue in
            AnalyticsRouter.enabled = newValue
        }
#endif
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This clears streaks, completions, and carb target so you can restart.")
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
        if clamped < 2 {
            hasSetCarbTarget = false
            storedCarbTarget = 0
        }
    }

    private func resetProgress() {
        storedCurrentDay = 1
        storedStreak = 0
        storedLastISO = ""
        hasOnboarded = false
        hasSetCarbTarget = false
        storedCarbTarget = 0
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
#endif
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ContentStore())
            .environmentObject(FeatureFlagStore())
    }
}
