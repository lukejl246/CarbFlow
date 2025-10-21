import SwiftUI
import Combine
import UIKit

struct HomeView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.streakCount) private var streakCount = 0
    @AppStorage(Keys.lastCompletionISO) private var lastCompletionISO = ""
    @AppStorage(Keys.username) private var username = ""
    @AppStorage(Keys.hasSetCarbTarget) private var hasSetCarbTarget = false
    @AppStorage(Keys.carbTarget) private var carbTarget = 0
    @AppStorage(Keys.isFasting) private var isFasting = false
    @AppStorage(Keys.fastingStart) private var fastingStart = 0.0
    @EnvironmentObject private var contentStore: ContentStore
    @EnvironmentObject private var quizStore: QuizStore
    @State private var isSettingsPresented = false
    @State private var now = Date()
    @State private var animatedProgress: Double = 0
    @State private var isStreakPulsing = false
    @State private var showInfoChips = false
    @State private var showRequirementBadges = false
    @State private var carbOverlayOpacity: Double = 0

    private static let fastingUnlockDay = 18

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var totalDays: Int { max(contentStore.totalDays, ProgramModel.modules.count) }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var greetingLine: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Welcome back" : "Welcome back, \(trimmed)"
    }

    private var todaysContent: ContentDay? {
        contentStore.day(currentDay)
    }

    private var fallbackModule: DayModule? {
        ProgramModel.modules.first(where: { $0.day == currentDay })
    }

    private var todayTitle: String {
        todaysContent?.title ?? fallbackModule?.title ?? "Day \(currentDay)"
    }

    private var todaySummary: String {
        todaysContent?.summary ?? fallbackModule?.summary ?? "Summary coming soon."
    }

    private var todayReadMinutes: Int {
        todaysContent?.readMins ?? 0
    }

    private var readDurationLabel: String {
        todayReadMinutes > 0 ? "~\(todayReadMinutes) min" : "~1 min"
    }

    private var requiresQuizToday: Bool {
        todaysContent?.requiresQuizCorrect ?? false
    }

    private var requiresCarbTargetToday: Bool {
        todaysContent?.requiresCarbTarget ?? (currentDay == 2)
    }

    private var carbCardUnlocked: Bool {
        currentDay > 2
    }

    private var todayMetrics: TodayMetrics {
        HomeMetricsBuilder.make(
            currentDay: currentDay,
            streakCount: streakCount,
            totalDays: totalDays,
            readMinutes: todayReadMinutes,
            requiresQuiz: requiresQuizToday,
            quizIsSatisfied: quizStore.isCorrect(day: currentDay),
            requiresCarbTarget: requiresCarbTargetToday,
            hasCarbSelection: hasSelectedCarbTarget
        )
    }

    private var heroSubtitle: String {
        "You're working on Day \(todayMetrics.currentDay) of \(todayMetrics.totalDays)"
    }

    private var progress: Double {
        min(Double(todayMetrics.currentDay), Double(todayMetrics.totalDays)) / Double(todayMetrics.totalDays)
    }

    private var streakDescriptor: String {
        todayMetrics.streakCount > 0 ? "\(todayMetrics.streakCount) day streak" : "No streak yet"
    }

    private var streakHint: String {
        todayMetrics.streakHint
    }

    private var fastingHeadline: String {
        isFasting ? "Fasting in progress" : "No fast running"
    }

    private var fastingDetail: String {
        if isFasting {
            let interval = max(now.timeIntervalSince1970 - fastingStart, 0)
            let elapsed = HomeView.durationFormatter.string(from: interval) ?? "--"
            return "\(elapsed) elapsed · manage in Timer tab."
        }
        return "Start a fast from the Timer tab whenever you're ready."
    }

    private var fastingCardUnlocked: Bool {
        currentDay > HomeView.fastingUnlockDay
    }

    private var moduleButtonTitle: String {
        currentDay <= 1 ? "Open Day 1" : "Open Day \(currentDay)"
    }

    private let accentPalette: [Color] = [
        Color(red: 0.42, green: 0.61, blue: 0.99),
        Color(red: 0.95, green: 0.65, blue: 0.28),
        Color(red: 0.42, green: 0.78, blue: 0.64),
        Color(red: 0.67, green: 0.58, blue: 0.95)
    ]

    private var todaySteps: [String] {
        var steps: [String] = []

        if todayReadMinutes > 0 {
            steps.append("Review the lesson (~\(todayReadMinutes) min read).")
        } else {
            steps.append("Review today's lesson content.")
        }

        if todayMetrics.pendingRequirements.contains(.carbTarget) {
            steps.append("Select a carb target before completing.")
        } else if requiresCarbTargetToday {
            steps.append("Carb target locked in at \(carbTarget) g.")
        }

        if requiresQuizToday {
            if todayMetrics.pendingRequirements.contains(.quiz) {
                steps.append("Take the quick quiz to unlock completion.")
            } else {
                steps.append("Quiz completed—review if you'd like.")
            }
        }

        steps.append("Mark the day complete when you're ready.")

        return deduplicated(steps)
    }

    @ViewBuilder
    private var infoChips: some View {
        let chips: [(String, String, Color)] = {
            var result: [(String, String, Color)] = []
            if todayReadMinutes > 0 {
                result.append(("clock", "~\(todayReadMinutes) min read", accentPalette[0]))
            }
            if carbCardUnlocked, hasSelectedCarbTarget {
                result.append(("leaf.fill", "\(carbTarget) g target", accentPalette[1]))
            }
            if requiresQuizToday {
                let tone = todayMetrics.hasPendingQuiz ? Color.orange : accentPalette[2]
                let text = todayMetrics.hasPendingQuiz ? "Quiz pending" : "Quiz done"
                result.append(("checklist", text, tone))
            }
            return result
        }()

        if showInfoChips, !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        DataChip(icon: chip.0, text: chip.1, tone: chip.2)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var requirementSection: some View {
        if todayMetrics.pendingRequirements.isEmpty {
            Text("All checkpoints cleared—complete when ready.")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Before completing:")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                if showRequirementBadges {
                    HStack(spacing: 10) {
                        ForEach(todayMetrics.pendingRequirements) { requirement in
                            RequirementBadge(requirement: requirement)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                if !todayMetrics.quizMessage.isEmpty {
                    Text(todayMetrics.quizMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var hasSelectedCarbTarget: Bool {
        hasSetCarbTarget && carbTarget > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                todayCard
                carbCard
                fastingCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .overlay(alignment: .top) {
            #if DEBUG
            DebugBanner(currentDay: currentDay, streak: streakCount, lastISO: lastCompletionISO)
                .padding(.top, 8)
            #endif
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsSheet(
                resetAction: resetProgress,
                totalDays: contentStore.totalDays,
                currentDay: currentDay
            )
        }
        .onReceive(timer) { date in
            now = date
        }
        .onAppear { prepareAnimations(initial: true) }
        .onChange(of: currentDay) { _ in prepareAnimations() }
        .onChange(of: streakCount) { _ in pulseStreak() }
        .onChange(of: hasSelectedCarbTarget) { _ in prepareAnimations() }
        .onChange(of: requiresQuizToday) { _ in prepareAnimations() }
        .onChange(of: carbCardUnlocked) { _ in animateCarbOverlay() }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("CarbFlow")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(Date.now.formatted(.dateTime.month().day().year()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                isSettingsPresented = true
            } label: {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
                    .overlay(
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var todayCard: some View {
        HomeCard(accentColor: accentPalette[0]) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(greetingLine)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(heroSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(accentPalette[0])
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Today", systemImage: "calendar.badge.clock")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Day \(todayMetrics.currentDay)/\(todayMetrics.totalDays)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(accentPalette[0])
                    }
                    ProgressView(value: animatedProgress)
                        .tint(accentPalette[0])
                        .padding(.top, 2)
                }

                infoChips

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Streak", systemImage: "flame.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(streakDescriptor)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(accentPalette[2])
                            .scaleEffect(isStreakPulsing ? 1.08 : 1)
                    }
                    Text(streakHint)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                requirementSection

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Today's lesson", systemImage: "text.book.closed.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(readDurationLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(todayTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(todaySummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(todaySteps, id: \.self) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "smallcircle.filled.circle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(step)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: DayDetailView(day: currentDay)) {
                        Text(moduleButtonTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentPalette[0], in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var carbCard: some View {
        HomeCard(accentColor: accentPalette[1]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Daily carb target", systemImage: "leaf.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    if hasSelectedCarbTarget {
                        Text("\(carbTarget) g")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accentPalette[1])
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(accentPalette[1].opacity(0.18))
                            )
                    } else if carbCardUnlocked {
                        Text("Not set")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                            )
                    }
                }

                Text(carbCardUnlocked ? "Carb target chosen on Day 2. Adjust anytime from settings." : "Finish Day 2 to unlock your personalized carb target.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(carbCardUnlocked ? 1 : 0.55)
        .overlay {
            if !carbCardUnlocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(carbOverlayOpacity)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .opacity(carbOverlayOpacity)
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(accentPalette[1])
                        Text("Unlock after Day 2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Complete the Day 2 lesson to set this target.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .opacity(carbOverlayOpacity)
                }
            }
        }
        .allowsHitTesting(carbCardUnlocked)
    }

    private var fastingCard: some View {
        HomeCard(accentColor: accentPalette[3]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Fasting status", systemImage: "bolt.heart")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(fastingHeadline)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(fastingDetail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill((isFasting ? accentPalette[3] : Color.gray).opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .fill(isFasting ? accentPalette[3] : Color.gray)
                                .frame(width: 12, height: 12)
                        )
                }
            }
        }
        .opacity(fastingCardUnlocked ? 1 : 0.55)
        .overlay {
            if !fastingCardUnlocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(accentPalette[3])
                        Text("Unlock after Day 18")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Complete the Day 18 lesson on meal timing to start tracking.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                }
            }
        }
        .allowsHitTesting(fastingCardUnlocked)
    }

    private func resetProgress() {
        currentDay = 1
        streakCount = 0
        lastCompletionISO = ""
        quizStore.resetProgress()
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func deduplicated(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.filter { seen.insert($0).inserted }
    }

    private func prepareAnimations(initial: Bool = false) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            animatedProgress = progress
        }

        let hasChips = (todayReadMinutes > 0) || (carbCardUnlocked && hasSelectedCarbTarget) || requiresQuizToday
        withAnimation(.easeOut(duration: initial ? 0.35 : 0.2)) {
            showInfoChips = hasChips
            showRequirementBadges = !todayMetrics.pendingRequirements.isEmpty
        }

        animateCarbOverlay()

        if !initial {
            pulseStreak()
        }
    }

    private func animateCarbOverlay() {
        let target = carbCardUnlocked ? 0.0 : 1.0
        withAnimation(.easeInOut(duration: 0.35)) {
            carbOverlayOpacity = target
        }
    }

    private func pulseStreak() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            isStreakPulsing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                isStreakPulsing = false
            }
        }
    }
}

private struct DataChip: View {
    let icon: String
    let text: String
    let tone: Color

    var body: some View {
        Label {
            Text(text)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: icon)
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tone.opacity(0.16))
        )
        .foregroundColor(tone)
    }
}

private struct RequirementBadge: View {
    let requirement: TodayMetrics.Requirement

    private var tone: Color {
        switch requirement {
        case .quiz: return .orange
        case .carbTarget: return .accentColor
        }
    }

    private var icon: String {
        switch requirement {
        case .quiz: return "checklist"
        case .carbTarget: return "leaf.fill"
        }
    }

    var body: some View {
        Label(requirement.label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tone.opacity(0.18))
            )
            .foregroundColor(tone)
    }
}

private enum Haptics {
    static func selection() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct HomeCard<Content: View>: View {
    private let accentColor: Color
    private let content: Content

    init(accentColor: Color, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: Color.black.opacity(0.04), radius: 12, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(accentColor.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SettingsSheet: View {
    let resetAction: () -> Void
    let totalDays: Int

    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(Keys.currentDay) private var storedCurrentDay = 1
    @AppStorage(Keys.streakCount) private var storedStreak = 0
    @AppStorage(Keys.lastCompletionISO) private var storedLastISO = ""
    @AppStorage(Keys.hasSetCarbTarget) private var hasSetCarbTarget = false
    @AppStorage(Keys.carbTarget) private var storedCarbTarget = 0

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int

    init(resetAction: @escaping () -> Void, totalDays: Int, currentDay: Int) {
        self.resetAction = resetAction
        self.totalDays = max(totalDays, 1)
        _selectedDay = State(initialValue: min(max(currentDay, 1), max(totalDays, 1)))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Progress") {
                    Stepper(value: $selectedDay, in: 1...max(totalDays, 1)) {
                        Text("Jump to Day \(selectedDay)")
                    }
                    Text("Current app day: \(storedCurrentDay)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Apply Day") {
                        applySelectedDay()
                        Haptics.selection()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Utilities") {
                    Button("Show Onboarding") {
                        hasOnboarded = false
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Reset Progress", role: .destructive) {
                        resetAction()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func applySelectedDay() {
        storedCurrentDay = selectedDay
        storedStreak = max(selectedDay - 1, 0)
        storedLastISO = ""
        if selectedDay < 2 {
            hasSetCarbTarget = false
            storedCarbTarget = 0
        }
    }
}

#if DEBUG
private struct DebugBanner: View {
    @State private var isVisible = true

    let currentDay: Int
    let streak: Int
    let lastISO: String

    var body: some View {
        if isVisible {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug streak state")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Day \(currentDay) • Streak \(streak)")
                        .font(.caption)
                    Text("Last ISO: \(lastISO.isEmpty ? "—" : lastISO)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
            )
            .padding(.horizontal, 20)
        }
    }
}
#endif

#Preview {
    let store = ContentStore()
    let quizStore = QuizStore(contentStore: store)
    return HomeView()
        .environmentObject(store)
        .environmentObject(quizStore)
}
