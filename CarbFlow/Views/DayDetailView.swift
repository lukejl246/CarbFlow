import SwiftUI

struct DayDetailView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.streakCount) private var streakCount = 0
    @AppStorage(Keys.lastCompletionISO) private var lastCompletionISO = ""
    @AppStorage(Keys.carbTarget) private var carbTarget = 30

    private let day: Int
    private let module: DayModule

    init(day: Int) {
        self.day = min(max(day, 1), ProgramModel.modules.count)
        self.module = ProgramModel.modules[min(max(day - 1, 0), ProgramModel.modules.count - 1)]
    }

    private var dayContent: DayContent {
        if let content = ProgramModel.contentByDay[day] {
            return content
        }
        return DayContent(
            keyIdea: "Stay consistent with your plan and reflect on what you learn today.",
            faqs: [
                "When in doubt, review the lesson and apply one small habit change."
            ]
        )
    }

    private var progress: Double {
        Double(day) / Double(ProgramModel.modules.count)
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

    private var isButtonDisabled: Bool {
        completionState != .available
    }

    private var buttonBackground: Color {
        completionState == .available ? Color.accentColor : Color.gray.opacity(0.2)
    }

    private var buttonForeground: Color {
        completionState == .available ? .white : .secondary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                keyIdeaSection
                faqSection
                carbPickerSection
                completeButton
            }
            .padding()
        }
        .navigationTitle("Day \(day)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var carbPickerSection: some View {
        Group {
            if day == 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your daily carb limit")
                        .font(.headline)
                    Picker("Daily carb target", selection: $carbTarget) {
                        ForEach([20, 30, 40, 50], id: \.self) { value in
                            Text("\(value) g").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day \(day) of \(ProgramModel.modules.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(module.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
    }

    private var keyIdeaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key idea")
                .font(.headline)
            Text(dayContent.keyIdea)
                .foregroundColor(.secondary)
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAQs")
                .font(.headline)

            ForEach(dayContent.faqs.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(dayContent.faqs[index])
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private var completeButton: some View {
        Button(action: markComplete) {
            Text(buttonTitle)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonBackground)
                .foregroundColor(buttonForeground)
                .cornerRadius(12)
        }
        .disabled(isButtonDisabled)
    }

    private func markComplete() {
        guard completionState == .available else {
            return
        }

        let today = Date()
        let todayString = today.isoDayString

        guard lastCompletionISO != todayString else {
            return
        }

        if let lastDate = Date.isoDayFormatter.date(from: lastCompletionISO),
           Calendar.current.isDateInYesterday(lastDate) {
            streakCount += 1
        } else {
            streakCount = 1
        }

        lastCompletionISO = todayString

        if currentDay < ProgramModel.modules.count {
            currentDay += 1
        }
    }
}

#Preview {
    NavigationStack {
        DayDetailView(day: 1)
    }
}
