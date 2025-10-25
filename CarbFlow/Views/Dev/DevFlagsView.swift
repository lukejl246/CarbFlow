#if DEBUG

import SwiftUI

struct DevFlagsView: View {
    @EnvironmentObject var flags: FeatureFlagStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                flagSection(title: "Core Features", mappings: primaryMappings)
                flagSection(title: "Quiz Modules", mappings: quizMappings)
                flagSection(title: "Dashboard Tiles", mappings: dashboardMappings)
                resetButton
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Developer Flags")
    }

    // MARK: - Flag Mappings

    private var primaryMappings: [FlagMapping] {
        [
            .init(flag: .logging, title: "Logging", get: { flags.loggingEnabled }, set: flags.setLogging),
            .init(flag: .recipes, title: "Recipes", get: { flags.recipesEnabled }, set: flags.setRecipes),
            .init(flag: .healthKit, title: "HealthKit", get: { flags.healthKitEnabled }, set: flags.setHealthKit),
            .init(flag: .wearables, title: "Wearables", get: { flags.wearablesEnabled }, set: flags.setWearables),
            .init(flag: .ketones, title: "Ketones", get: { flags.ketonesEnabled }, set: flags.setKetones),
            .init(flag: .coach, title: "Coach", get: { flags.coachEnabled }, set: flags.setCoach),
            .init(flag: .quizzes, title: "Quizzes", get: { flags.quizzesEnabled }, set: flags.setQuizzes),
            .init(flag: .programme, title: "Programme", get: { flags.programmeEnabled }, set: flags.setProgramme),
            .init(flag: .challenges, title: "Challenges", get: { flags.challengesEnabled }, set: flags.setChallenges),
            .init(flag: .fasting, title: "Fasting", get: { flags.fastingEnabled }, set: flags.setFasting)
        ]
    }

    private var quizMappings: [FlagMapping] {
        [
            .init(flag: .quizBasics, title: "Quiz: Basics", get: { flags.quizBasicsEnabled }, set: flags.setQuizBasics),
            .init(flag: .quizLabels, title: "Quiz: Labels", get: { flags.quizLabelsEnabled }, set: flags.setQuizLabels),
            .init(flag: .quizElectrolytes, title: "Quiz: Electrolytes", get: { flags.quizElectrolytesEnabled }, set: flags.setQuizElectrolytes),
            .init(flag: .quizFasting101, title: "Quiz: Fasting 101", get: { flags.quizFasting101Enabled }, set: flags.setQuizFasting101)
        ]
    }

    private var dashboardMappings: [FlagMapping] {
        [
            .init(flag: .dashboardSummary, title: "Summary", get: { flags.dashboardSummaryEnabled }, set: flags.setDashboardSummary),
            .init(flag: .dashboardTrends, title: "Trends", get: { flags.dashboardTrendsEnabled }, set: flags.setDashboardTrends),
            .init(flag: .dashboardStreaks, title: "Streaks", get: { flags.dashboardStreaksEnabled }, set: flags.setDashboardStreaks),
            .init(flag: .dashboardMacros, title: "Macros", get: { flags.dashboardMacrosEnabled }, set: flags.setDashboardMacros),
            .init(flag: .dashboardHydration, title: "Hydration", get: { flags.dashboardHydrationEnabled }, set: flags.setDashboardHydration),
            .init(flag: .dashboardSleep, title: "Sleep", get: { flags.dashboardSleepEnabled }, set: flags.setDashboardSleep),
            .init(flag: .dashboardReadiness, title: "Readiness", get: { flags.dashboardReadinessEnabled }, set: flags.setDashboardReadiness)
        ]
    }

    private var challengeMappings: [FlagMapping] {
        [
            .init(flag: .challengeElectrolytes7d, title: "Challenge: Electrolytes 7d", get: { flags.challengeElectrolytes7dEnabled }, set: flags.setChallengeElectrolytes7d),
            .init(flag: .challengeHydration7d, title: "Challenge: Hydration 7d", get: { flags.challengeHydration7dEnabled }, set: flags.setChallengeHydration7d),
            .init(flag: .challengeSteps7d, title: "Challenge: Steps 7d", get: { flags.challengeSteps7dEnabled }, set: flags.setChallengeSteps7d),
            .init(flag: .challengeNoSugar7d, title: "Challenge: No Sugar 7d", get: { flags.challengeNoSugar7dEnabled }, set: flags.setChallengeNoSugar7d)
        ]
    }

    private var allMappings: [FlagMapping] {
        primaryMappings + quizMappings + dashboardMappings + challengeMappings
    }

    // MARK: - Views

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
                .fill(Color.white)
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

    // MARK: - Helpers

    private func binding(for mapping: FlagMapping) -> Binding<Bool> {
        Binding(
            get: { mapping.get() },
            set: { newValue in mapping.set(newValue) }
        )
    }

    private func resetFlags() {
        let defaults = CFFeatureFlags.shared
        defaults.resetToDefaults()
        for mapping in allMappings {
            mapping.set(defaults.isEnabled(mapping.flag))
        }
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
