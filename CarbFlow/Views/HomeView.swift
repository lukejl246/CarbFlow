import SwiftUI

struct HomeView: View {
    @EnvironmentObject var contentStore: ContentStore
    @AppStorage("cf_currentDay") private var cf_currentDay = 1
    @AppStorage("cf_carbTarget") private var cf_carbTarget = 0
    @AppStorage("cf_quizCorrectDays") private var quizCorrectDaysStorage: String = "[]"

    @State private var navigateToDayDetail = false
    @State private var navigateToFastingTimer = false
    @State private var activeAlert: AlertType?

    private var totalDays: Int {
        max(contentStore.totalDays, 1)
    }

    private var day: Int {
        max(1, min(cf_currentDay, totalDays))
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
        cf_carbTarget != 0
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
                    destination: FastingTimerView(),
                    isActive: $navigateToFastingTimer
                ) { EmptyView() }
            }
        )
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Got it"))
            )
        }
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
                value: hasCarb ? "\(cf_carbTarget) g" : "— g",
                subtitle: "Set in Day 2",
                tint: .green
            ) {
                activeAlert = .carbs
            },
            DashboardItem(
                icon: "timer",
                title: "Fasting",
                value: "Not fasting",
                tint: .orange
            ) {
                navigateToFastingTimer = true
            },
            DashboardItem(
                icon: "moon.fill",
                title: "Sleep",
                value: "— h",
                subtitle: "Add later",
                tint: .indigo
            ) {
                activeAlert = .sleep
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private enum AlertType: Identifiable {
        case carbs
        case sleep

        var id: Int {
            hashValue
        }

        var title: String {
            switch self {
            case .carbs:
                return "Carb tracking"
            case .sleep:
                return "Sleep tracking"
            }
        }

        var message: String {
            switch self {
            case .carbs:
                return "Carb logging will arrive in a future update."
            case .sleep:
                return "Sleep insights are on the roadmap. Stay tuned!"
            }
        }
    }
}

#Preview {
    let store = ContentStore()
    return NavigationStack {
        HomeView()
            .environmentObject(store)
    }
}
