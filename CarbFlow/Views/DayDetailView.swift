import SwiftUI

struct DayDetailView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.streakCount) private var streakCount = 0
    @AppStorage(Keys.lastCompletionISO) private var lastCompletionISO = ""
    @AppStorage(Keys.carbTarget) private var carbTarget = 0
    @AppStorage(Keys.hasSetCarbTarget) private var hasSetCarbTarget = false

    @EnvironmentObject private var contentStore: ContentStore
    @EnvironmentObject private var quizStore: QuizStore
    @EnvironmentObject private var listStore: ContentListStore
    @Environment(\.dismiss) private var dismiss

    @State private var day2Selection: Int = -1
    @State private var showQuizSheet = false

    let day: Int

    private let carbOptions = [20, 30, 40, 50]

    private var storeTotalDays: Int {
        contentStore.totalDays
    }

    private var totalDays: Int {
        max(storeTotalDays, 1)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var isDayValid: Bool {
        storeTotalDays > 0 && (1...storeTotalDays).contains(day)
    }

    private var contentDay: ContentDay {
        contentStore.day(day) ?? ContentDay(
            day: day,
            title: "Day \(day)",
            summary: "Content coming soon.",
            keyIdea: "Stay consistent—more lessons are on the way.",
            faqs: [],
            readMins: 0,
            tags: [],
            prerequisites: [],
            requiresCarbTarget: day == 2,
            requiresQuizCorrect: false,
            listRefs: [],
            evidenceIds: []
        )
    }

    private var progressValue: Double {
        Double(min(max(day, 1), totalDays))
    }

    private enum CompletionState {
        case available
        case locked
        case alreadyComplete
    }

    private var completionState: CompletionState {
        if day < currentDay {
            return .alreadyComplete
        } else if day == currentDay {
            return .available
        } else {
            return .locked
        }
    }

    private var buttonTitle: String {
        switch completionState {
        case .available:
            return "Mark day complete"
        case .locked:
            return "Complete earlier days first"
        case .alreadyComplete:
            return "Already completed"
        }
    }

    private var requiresQuiz: Bool {
        contentDay.requiresQuizCorrect
    }

    private var quizIsSatisfied: Bool {
        guard requiresQuiz else { return true }
        return quizStore.isCorrect(day: day)
    }

    private var isButtonDisabled: Bool {
        if completionState != .available {
            return true
        }
        if contentDay.requiresCarbTarget && day2Selection < 0 {
            return true
        }
        if !quizIsSatisfied {
            return true
        }
        return false
    }

    private var buttonBackground: Color {
        isButtonDisabled ? Color.gray.opacity(0.2) : Color.accentColor
    }

    private var buttonForeground: Color {
        isButtonDisabled ? .secondary : .white
    }

    var body: some View {
        Group {
            if isDayValid {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        keyIdeaCard
                        faqCard
                        listCards
                        carbCard
                        quizCard
                        completionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            } else {
                unavailableSection
            }
        }
        .navigationTitle(isDayValid ? "Day \(day)" : "Day not available")
        .navigationBarTitleDisplayMode(.inline)
        .background(backgroundGradient.ignoresSafeArea())
        .sheet(isPresented: $showQuizSheet) {
            if isDayValid, let quiz = quizStore.quiz(for: day) {
                QuizSheet(
                    quiz: quiz,
                    isPresented: $showQuizSheet,
                    hasStoredCorrectAnswer: quizStore.isCorrect(day: day)
                ) {
                    quizStore.markCorrect(day: day)
                }
            } else {
                Text("Quiz unavailable")
                    .padding()
            }
        }
        .onAppear {
            guard isDayValid else { return }
            if contentDay.requiresCarbTarget && day2Selection == -1 {
                if let index = carbOptions.firstIndex(of: carbTarget), hasSetCarbTarget {
                    day2Selection = index
                } else {
                    day2Selection = -1
                }
            }
        }
    }

    private var headerCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Day \(day) of \(totalDays)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(contentDay.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)

                if contentDay.readMins > 0 {
                    Label("\(contentDay.readMins) min read", systemImage: "clock")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Text(contentDay.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: progressValue, total: Double(totalDays))
                    .tint(Color.accentColor)
            }
        }
    }

    private var keyIdeaCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Key idea")
                    .font(.headline)
                Text(contentDay.keyIdea)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var faqCard: some View {
        Group {
            if !contentDay.faqs.isEmpty {
                DetailCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FAQs")
                            .font(.headline)

                        ForEach(Array(contentDay.faqs.enumerated()), id: \.offset) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "smallcircle.filled.circle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(item.element)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private var listCards: some View {
        Group {
            ForEach(contentDay.listRefs, id: \.self) { listID in
                if let list = listStore.list(with: listID) {
                    DetailCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(list.title)
                                .font(.headline)
                            ForEach(list.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "smallcircle.filled.circle")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(item)
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                } else {
                    DetailCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List updating soon")
                                .font(.headline)
                            Text("We’re refreshing this lesson’s list. Check back shortly.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var carbCard: some View {
        Group {
            if contentDay.requiresCarbTarget {
                DetailCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your daily carb limit")
                            .font(.headline)
                        Picker("Daily carb target", selection: $day2Selection) {
                            ForEach(0..<carbOptions.count, id: \.self) { index in
                                Text("\(carbOptions[index]) g").tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: day2Selection) { newIndex in
                            if newIndex >= 0 {
                                let value = carbOptions[newIndex]
                                carbTarget = value
                                hasSetCarbTarget = true
                            } else {
                                carbTarget = 0
                                hasSetCarbTarget = false
                            }
                        }

                        if day2Selection < 0 {
                            Text("Pick a carb target to continue.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var quizCard: some View {
        Group {
            if requiresQuiz {
                if quizStore.quiz(for: day) != nil {
                    DetailCard(accent: quizIsSatisfied ? .green : .accentColor, tintBackground: true) {
                        let accent = quizIsSatisfied ? Color.green : Color.accentColor
                        VStack(alignment: .leading, spacing: 14) {
                            Label(quizIsSatisfied ? "Quiz complete" : "Quick quiz", systemImage: quizIsSatisfied ? "checkmark.circle.fill" : "questionmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(accent)

                            Text(quizIsSatisfied ? "You can review your answer anytime." : "Answer this quick question to unlock the completion button.")
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            Button {
                                showQuizSheet = true
                            } label: {
                                Text(quizIsSatisfied ? "Review quiz" : "Take quiz")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                } else {
                    DetailCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quiz coming soon.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

private var completionCard: some View {
    DetailCard {
        Button(action: markComplete) {
            Text(buttonTitle)
                .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(buttonBackground)
                    .foregroundColor(buttonForeground)
                    .cornerRadius(14)
            }
            .disabled(isButtonDisabled)
        }
    }

    private var unavailableSection: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Day not available")
                .font(.title3.weight(.semibold))
            Text("Please choose a day between 1 and \(max(storeTotalDays, 1)).")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button {
                dismiss()
            } label: {
                Text("Return to Today")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .padding()
    }

    private func markComplete() {
        guard completionState == .available else { return }
        if contentDay.requiresCarbTarget && day2Selection < 0 { return }
        if !quizIsSatisfied { return }

        let calendar = Calendar.current
        let now = Date()
        let trimmedLastISO = lastCompletionISO.isEmpty ? nil : lastCompletionISO
        let result = StreakLogic.computeNewStreak(
            lastISO: trimmedLastISO,
            now: now,
            currentStreak: streakCount,
            calendar: calendar
        )

        guard !(result.todayISO == trimmedLastISO && result.newStreak == streakCount) else {
            return
        }

        streakCount = result.newStreak
        lastCompletionISO = result.todayISO

        if currentDay < contentStore.totalDays {
            currentDay += 1
        }
    }
}

private struct DetailCard<Content: View>: View {
    private let accent: Color
    private let tintBackground: Bool
    private let content: Content

    init(accent: Color = Color.accentColor, tintBackground: Bool = false, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.tintBackground = tintBackground
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    tintBackground
                    ? accent.opacity(0.12)
                    : Color.white.opacity(0.96)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 12, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(accent.opacity(tintBackground ? 0.24 : 0.14), lineWidth: 1)
        )
    }
}

#Preview {
    let store = ContentStore()
    let quizStore = QuizStore(contentStore: store)
    let listStore = ContentListStore()
    return NavigationStack {
        DayDetailView(day: 1)
            .environmentObject(store)
            .environmentObject(quizStore)
            .environmentObject(listStore)
    }
}
