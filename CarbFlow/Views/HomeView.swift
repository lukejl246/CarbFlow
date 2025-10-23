import SwiftUI

struct HomeView: View {
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject private var carbStore: CarbIntakeStore
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.carbTarget) private var carbTarget = 0
    @AppStorage("cf_quizCorrectDays") private var quizCorrectDaysStorage: String = "[]"

    @State private var navigateToDayDetail = false
    @State private var navigateToFastingTimer = false
    @State private var navigateToCarbTracker = false
    @State private var navigateToSleep = false
    @State private var alertConfig: AlertConfig?
    @State private var showLearnReminder = false

    private var totalDays: Int {
        max(contentStore.totalDays, 1)
    }

    private var day: Int {
        max(1, min(currentDay, totalDays))
    }

    private var today: ContentDay? {
        contentStore.day(day)
    }

    private var quizCorrectDays: Set<Int> {
        guard let data = quizCorrectDaysStorage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    private var requiresQuiz: Bool {
        today?.requiresQuizCorrect ?? false
    }

    private var quizDone: Bool {
        quizCorrectDays.contains(day)
    }

    private var requiresCarb: Bool {
        today?.requiresCarbTarget ?? false
    }

    private var hasCarb: Bool {
        carbTarget != 0
    }

    private var carbsLeft: Int? {
        hasCarb ? carbStore.gramsLeft(target: carbTarget) : nil
    }

    private var hasCompletedDay2: Bool {
        currentDay >= 3
    }

    private var fastingUnlockDay: Int {
        contentStore.days.first {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveContains("Meal Timing")
        }?.day ?? 5
    }

    private var isFastingUnlocked: Bool {
        currentDay > fastingUnlockDay
    }

    private var sleepUnlockDay: Int {
        contentStore.days.first {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveContains("Sleep & Recovery")
        }?.day ?? 22
    }

    private var isSleepUnlocked: Bool {
        currentDay > sleepUnlockDay
    }

    private var canComplete: Bool {
        (!requiresQuiz || quizDone) && (!requiresCarb || hasCarb)
    }

    private var cardHeading: String {
        if let title = today?.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Today: \(title)"
        }
        return "Today"
    }

    private var summaryText: String {
        today?.summary ?? "Preview the lesson and keep momentum going."
    }

    private var readDurationText: String {
        guard let mins = today?.readMins, mins > 0 else {
            return "—"
        }
        return "~\(mins) min"
    }

    private var ctaTitle: String {
        canComplete ? "Continue Day \(day)" : "Start Day \(day)"
    }

    private var formattedDate: String {
        HomeView.dateFormatter.string(from: Date())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                    .padding(.horizontal, 20)

                heroCard
                    .padding(.horizontal, 20)

                DashboardGrid(title: "Dashboard", items: dashboardItems)
            }
            .padding(.top, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                }
                .accessibilityLabel("Open Settings")
            }
        }
        .background(
            Group {
                NavigationLink(
                    destination: DayDetailView(day: day),
                    isActive: $navigateToDayDetail
                ) { EmptyView() }
                NavigationLink(
                    destination: CarbTrackerView(),
                    isActive: $navigateToCarbTracker
                ) { EmptyView() }
                NavigationLink(
                    destination: FastingTimerView(),
                    isActive: $navigateToFastingTimer
                ) { EmptyView() }
                NavigationLink(
                    destination: SleepInsightsView(),
                    isActive: $navigateToSleep
                ) { EmptyView() }
            }
        )
        .alert(item: $alertConfig) { $0.build() }
        .alert("Learn Sleep & Recovery", isPresented: $showLearnReminder, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text("Switch to the Learn tab and complete Sleep & Recovery to unlock sleep tracking.")
        })
    }

    private var dashboardItems: [DashboardItem] {
        [
            DashboardItem(
                icon: "checkmark.circle",
                title: "Progress",
                value: "\(day)/\(totalDays)",
                tint: .blue
            ) {
                navigateToDayDetail = true
            },
            DashboardItem(
                icon: "leaf",
                title: "Carbs",
                value: hasCompletedDay2 ? (carbsLeft.map { "\($0) g" } ?? "— g") : "Locked",
                subtitle: hasCompletedDay2
                    ? (hasCarb ? "Target \(carbTarget) g" : "Set in Day 2")
                    : "Complete Day 2",
                tint: hasCompletedDay2 ? .green : Color(.systemGray3)
            ) {
                handleCarbTileTap()
            },
            DashboardItem(
                icon: "timer",
                title: "Fasting",
                value: isFastingUnlocked ? "Not fasting" : "Locked",
                subtitle: isFastingUnlocked ? nil : "Complete Meal Timing",
                tint: isFastingUnlocked ? .orange : Color(.systemGray3)
            ) {
                handleFastingTileTap()
            },
            DashboardItem(
                icon: "moon.fill",
                title: "Sleep",
                value: isSleepUnlocked ? "— h" : "Locked",
                subtitle: isSleepUnlocked ? "Add later" : "Complete Sleep & Recovery",
                tint: isSleepUnlocked ? .indigo : Color(.systemGray3)
            ) {
                handleSleepTileTap()
            }
        ]
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CarbFlow")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            HStack(alignment: .center, spacing: 12) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Day \(day) of \(totalDays)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }

            ProgressView(value: Double(day), total: Double(totalDays))
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(cardHeading)
                    .font(.title3.weight(.semibold))
                Text(summaryText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            VStack(spacing: 12) {
                checklistRow(
                    icon: "text.book.closed",
                    title: "Read",
                    subtitle: readDurationText,
                    statusText: nil,
                    statusColor: .secondary,
                    isDisabled: false
                )
                checklistRow(
                    icon: "questionmark.circle",
                    title: "Quiz",
                    subtitle: requiresQuiz ? "Required" : "Optional",
                    statusText: requiresQuiz && !quizDone ? "Pending" : "Done",
                    statusColor: requiresQuiz && !quizDone ? .orange : .green,
                    isDisabled: false
                )
                checklistRow(
                    icon: "checkmark.seal",
                    title: "Mark complete",
                    subtitle: "Finish in Day detail",
                    statusText: canComplete ? "Ready" : "Locked",
                    statusColor: canComplete ? .accentColor : .secondary,
                    isDisabled: !canComplete
                )
            }

            NavigationLink {
                DayDetailView(day: day)
            } label: {
                Text(ctaTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private func checklistRow(
        icon: String,
        title: String,
        subtitle: String?,
        statusText: String?,
        statusColor: Color,
        isDisabled: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundColor(isDisabled ? .secondary : .accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isDisabled ? .secondary : .primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let statusText {
                Text(statusText)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 10)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private func handleCarbTileTap() {
        if hasCompletedDay2 {
            navigateToCarbTracker = true
        } else {
            alertConfig = AlertConfig(
                title: "Unlock Carbs",
                message: "Complete Day 2 (Carb Targets) to enable tracking.",
                primary: .default(Text("Go to Today")) {
                    navigateToDayDetail = true
                },
                secondary: .cancel()
            )
        }
    }

    private func handleFastingTileTap() {
        if isFastingUnlocked {
            navigateToFastingTimer = true
        } else {
            alertConfig = AlertConfig(
                title: "Unlock Fasting",
                message: "Complete Meal Timing to enable the fasting timer.",
                primary: .default(Text("Go to Today")) {
                    navigateToDayDetail = true
                },
                secondary: .cancel()
            )
        }
    }

    private func handleSleepTileTap() {
        if isSleepUnlocked {
            navigateToSleep = true
        } else {
            alertConfig = AlertConfig(
                title: "Unlock Sleep",
                message: "Complete Sleep & Recovery to enable sleep insights.",
                primary: .default(Text("Go to Today")) {
                    navigateToDayDetail = true
                },
                secondary: .default(Text("Learn")) {
                    showLearnReminder = true
                }
            )
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private struct AlertConfig: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primary: Alert.Button?
        let secondary: Alert.Button?

        func build() -> Alert {
            if let primary, let secondary {
                return Alert(title: Text(title), message: Text(message), primaryButton: primary, secondaryButton: secondary)
            } else if let primary {
                return Alert(title: Text(title), message: Text(message), dismissButton: primary)
            } else {
                return Alert(title: Text(title), message: Text(message))
            }
        }
    }
}

#Preview {
    let store = ContentStore()
    let carbStore = CarbIntakeStore()
    return NavigationStack {
        HomeView()
            .environmentObject(store)
            .environmentObject(carbStore)
    }
}
