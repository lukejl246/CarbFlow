#if DEBUG

import SwiftUI

/// Offline behaviour: toggles mutate in-memory UserDefaults-backed flags only; no network calls occur.
struct DevFlagsView: View {
    @EnvironmentObject var flags: FeatureFlagStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                flagSection(title: "Core Features", mappings: primaryMappings)
                flagSection(title: "Quiz Modules", mappings: quizMappings)
                flagSection(title: "Dashboard Tiles", mappings: dashboardMappings)
                flagSection(title: "Challenges", mappings: challengeMappings)
                qaToolsSection
                resetButton
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Developer Flags")
        .onAppear {
            cf_logEvent("flags-open", ["ts": Date().timeIntervalSince1970])
        }
        .onDisappear {
            cf_logEvent("flags-close", ["ts": Date().timeIntervalSince1970])
        }
    }

    private var primaryMappings: [FlagMapping] {
        [
            .init(flag: .logging, title: "Logging", get: { flags.loggingEnabled }, set: { flags.set(.logging, enabled: $0) }),
            .init(flag: .recipes, title: "Recipes", get: { flags.recipesEnabled }, set: { flags.set(.recipes, enabled: $0) }),
            .init(flag: .healthKit, title: "HealthKit", get: { flags.healthKitEnabled }, set: { flags.set(.healthKit, enabled: $0) }),
            .init(flag: .wearables, title: "Wearables", get: { flags.wearablesEnabled }, set: { flags.set(.wearables, enabled: $0) }),
            .init(flag: .ketones, title: "Ketones", get: { flags.ketonesEnabled }, set: { flags.set(.ketones, enabled: $0) }),
            .init(flag: .coach, title: "Coach", get: { flags.coachEnabled }, set: { flags.set(.coach, enabled: $0) }),
            .init(flag: .quizzes, title: "Quizzes", get: { flags.quizzesEnabled }, set: { flags.set(.quizzes, enabled: $0) }),
            .init(flag: .programme, title: "Programme", get: { flags.programmeEnabled }, set: { flags.set(.programme, enabled: $0) }),
            .init(flag: .challenges, title: "Challenges", get: { flags.challengesEnabled }, set: { flags.set(.challenges, enabled: $0) }),
            .init(flag: .fasting, title: "Fasting", get: { flags.fastingEnabled }, set: { flags.set(.fasting, enabled: $0) })
        ]
    }

    private var quizMappings: [FlagMapping] {
        [
            .init(flag: .quizBasics, title: "Quiz: Basics", get: { flags.quizBasicsEnabled }, set: { flags.set(.quizBasics, enabled: $0) }),
            .init(flag: .quizLabels, title: "Quiz: Labels", get: { flags.quizLabelsEnabled }, set: { flags.set(.quizLabels, enabled: $0) }),
            .init(flag: .quizElectrolytes, title: "Quiz: Electrolytes", get: { flags.quizElectrolytesEnabled }, set: { flags.set(.quizElectrolytes, enabled: $0) }),
            .init(flag: .quizFasting101, title: "Quiz: Fasting 101", get: { flags.quizFasting101Enabled }, set: { flags.set(.quizFasting101, enabled: $0) })
        ]
    }

    private var dashboardMappings: [FlagMapping] {
        [
            .init(flag: .dashboardSummary, title: "Dashboard: Summary", get: { flags.dashboardSummaryEnabled }, set: { flags.set(.dashboardSummary, enabled: $0) }),
            .init(flag: .dashboardTrends, title: "Dashboard: Trends", get: { flags.dashboardTrendsEnabled }, set: { flags.set(.dashboardTrends, enabled: $0) }),
            .init(flag: .dashboardStreaks, title: "Dashboard: Streaks", get: { flags.dashboardStreaksEnabled }, set: { flags.set(.dashboardStreaks, enabled: $0) }),
            .init(flag: .dashboardMacros, title: "Dashboard: Macros", get: { flags.dashboardMacrosEnabled }, set: { flags.set(.dashboardMacros, enabled: $0) }),
            .init(flag: .dashboardHydration, title: "Dashboard: Hydration", get: { flags.dashboardHydrationEnabled }, set: { flags.set(.dashboardHydration, enabled: $0) }),
            .init(flag: .dashboardSleep, title: "Dashboard: Sleep", get: { flags.dashboardSleepEnabled }, set: { flags.set(.dashboardSleep, enabled: $0) }),
            .init(flag: .dashboardReadiness, title: "Dashboard: Readiness", get: { flags.dashboardReadinessEnabled }, set: { flags.set(.dashboardReadiness, enabled: $0) })
        ]
    }

    private var challengeMappings: [FlagMapping] {
        [
            .init(flag: .challengeElectrolytes7d, title: "Challenge: Electrolytes 7d", get: { flags.challengeElectrolytes7dEnabled }, set: { flags.set(.challengeElectrolytes7d, enabled: $0) }),
            .init(flag: .challengeHydration7d, title: "Challenge: Hydration 7d", get: { flags.challengeHydration7dEnabled }, set: { flags.set(.challengeHydration7d, enabled: $0) }),
            .init(flag: .challengeSteps7d, title: "Challenge: Steps 7d", get: { flags.challengeSteps7dEnabled }, set: { flags.set(.challengeSteps7d, enabled: $0) }),
            .init(flag: .challengeNoSugar7d, title: "Challenge: No Sugar 7d", get: { flags.challengeNoSugar7dEnabled }, set: { flags.set(.challengeNoSugar7d, enabled: $0) })
        ]
    }

    private var allMappings: [FlagMapping] {
        primaryMappings + quizMappings + dashboardMappings + challengeMappings
    }

    private func flagSection(title: String, mappings: [FlagMapping]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            ForEach(mappings) { mapping in
                Toggle(mapping.title, isOn: binding(for: mapping))
                    .tint(.accentColor)
                    .frame(minHeight: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .contain)
    }

    private var qaToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QA Tools")
                .font(.headline)

            NavigationLink(destination: DevQAFoodVerificationView()) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    Text("Food Verification QA")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .contain)
    }

    private var resetButton: some View {
        Button(action: resetFlags) {
            Text("Reset to defaults")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func binding(for mapping: FlagMapping) -> Binding<Bool> {
        Binding(
            get: { mapping.get() },
            set: { newValue in
                mapping.set(newValue)
                cf_logEvent("flag-toggle", [
                    "ts": Date().timeIntervalSince1970,
                    "flag": mapping.flag.rawValue,
                    "value": newValue
                ])
            }
        )
    }

    private func resetFlags() {
        flags.resetToDefaults()
    }

    private struct FlagMapping: Identifiable {
        let flag: FeatureFlag
        let title: String
        let get: () -> Bool
        let set: (Bool) -> Void

        var id: String { flag.rawValue }
    }
}

#endif
