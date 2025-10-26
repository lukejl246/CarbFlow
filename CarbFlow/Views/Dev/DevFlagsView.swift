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
        var mappings: [FlagMapping] = []
        mappings.append(.init(flag: .logging, title: "Logging", get: { flags.loggingEnabled }, set: flags.setLogging))
        mappings.append(.init(flag: .recipes, title: "Recipes", get: { flags.recipesEnabled }, set: flags.setRecipes))
        mappings.append(.init(flag: .healthKit, title: "HealthKit", get: { flags.healthKitEnabled }, set: flags.setHealthKit))
        mappings.append(.init(flag: .wearables, title: "Wearables", get: { flags.wearablesEnabled }, set: flags.setWearables))
        mappings.append(.init(flag: .ketones, title: "Ketones", get: { flags.ketonesEnabled }, set: flags.setKetones))
        mappings.append(.init(flag: .coach, title: "Coach", get: { flags.coachEnabled }, set: flags.setCoach))
        mappings.append(.init(flag: .quizzes, title: "Quizzes", get: { flags.quizzesEnabled }, set: flags.setQuizzes))
        mappings.append(.init(flag: .programme, title: "Programme", get: { flags.programmeEnabled }, set: flags.setProgramme))
        mappings.append(.init(flag: .challenges, title: "Challenges", get: { flags.challengesEnabled }, set: flags.setChallenges))
        mappings.append(.init(flag: .fasting, title: "Fasting", get: { flags.fastingEnabled }, set: flags.setFasting))
        return mappings
    }

    private var quizMappings: [FlagMapping] {
        var mappings: [FlagMapping] = []
        mappings.append(.init(flag: .quizBasics, title: "Quiz: Basics", get: { flags.quizBasicsEnabled }, set: flags.setQuizBasics))
        mappings.append(.init(flag: .quizLabels, title: "Quiz: Labels", get: { flags.quizLabelsEnabled }, set: flags.setQuizLabels))
        mappings.append(.init(flag: .quizElectrolytes, title: "Quiz: Electrolytes", get: { flags.quizElectrolytesEnabled }, set: flags.setQuizElectrolytes))
        mappings.append(.init(flag: .quizFasting101, title: "Quiz: Fasting 101", get: { flags.quizFasting101Enabled }, set: flags.setQuizFasting101))
        return mappings
    }

    private var dashboardMappings: [FlagMapping] {
        var mappings: [FlagMapping] = []
        mappings.append(.init(flag: .dashboardSummary, title: "Summary", get: { flags.dashboardSummaryEnabled }, set: flags.setDashboardSummary))
        mappings.append(.init(flag: .dashboardTrends, title: "Trends", get: { flags.dashboardTrendsEnabled }, set: flags.setDashboardTrends))
        mappings.append(.init(flag: .dashboardStreaks, title: "Streaks", get: { flags.dashboardStreaksEnabled }, set: flags.setDashboardStreaks))
        mappings.append(.init(flag: .dashboardMacros, title: "Macros", get: { flags.dashboardMacrosEnabled }, set: flags.setDashboardMacros))
        mappings.append(.init(flag: .dashboardHydration, title: "Hydration", get: { flags.dashboardHydrationEnabled }, set: flags.setDashboardHydration))
        mappings.append(.init(flag: .dashboardSleep, title: "Sleep", get: { flags.dashboardSleepEnabled }, set: flags.setDashboardSleep))
        mappings.append(.init(flag: .dashboardReadiness, title: "Readiness", get: { flags.dashboardReadinessEnabled }, set: flags.setDashboardReadiness))
        return mappings
    }

    private var challengeMappings: [FlagMapping] {
        var mappings: [FlagMapping] = []
        mappings.append(.init(flag: .challengeElectrolytes7d, title: "Challenge: Electrolytes 7d", get: { flags.challengeElectrolytes7dEnabled }, set: flags.setChallengeElectrolytes7d))
        mappings.append(.init(flag: .challengeHydration7d, title: "Challenge: Hydration 7d", get: { flags.challengeHydration7dEnabled }, set: flags.setChallengeHydration7d))
        mappings.append(.init(flag: .challengeSteps7d, title: "Challenge: Steps 7d", get: { flags.challengeSteps7dEnabled }, set: flags.setChallengeSteps7d))
        mappings.append(.init(flag: .challengeNoSugar7d, title: "Challenge: No Sugar 7d", get: { flags.challengeNoSugar7dEnabled }, set: flags.setChallengeNoSugar7d))
        return mappings
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
