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
                Button("Show Onboarding") {
                    hasOnboarded = false
                }
                .buttonStyle(.bordered)

#if DEBUG
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
        }
        .onChange(of: storedCurrentDay) { _ in
            syncSelectedDay()
        }
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This clears streaks, completions, and carb target so you can restart.")
        }
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
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ContentStore())
            .environmentObject(FeatureFlagStore())
    }
}
