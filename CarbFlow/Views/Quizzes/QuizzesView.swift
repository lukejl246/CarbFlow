import SwiftUI

struct QuizzesView: View {
    @EnvironmentObject private var flags: FeatureFlagStore
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !visibleCards.isEmpty {
                    ForEach(visibleCards) { card in
                        card.view
                            .frame(minHeight: 120, alignment: .leading)
                    }
                } else {
                    placeholderCard
                        .frame(minHeight: 120, alignment: .leading)
                        .opacity(isVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isVisible = true
                            }
                        }
                        .onDisappear {
                            isVisible = false
                        }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Quizzes")
        .animation(.easeInOut(duration: 0.25), value: flags.quizzesEnabled)
        .animation(.easeInOut(duration: 0.25), value: visibleCards)
    }

    private var visibleCards: [QuizCard] {
        var cards: [QuizCard] = []
        if flags.quizBasicsEnabled { cards.append(.basics) }
        if flags.quizLabelsEnabled { cards.append(.labels) }
        if flags.quizElectrolytesEnabled { cards.append(.electrolytes) }
        if flags.quizFasting101Enabled { cards.append(.fasting101) }
        return cards
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.purple.opacity(0.7))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quizzes coming soon")
                        .font(.headline)
                    Text("Expect short, interactive check-ins to reinforce each day’s learning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .contain)
    }
}

private enum QuizCard: String, Identifiable, CaseIterable {
    case basics
    case labels
    case electrolytes
    case fasting101

    var id: String { rawValue }

    @ViewBuilder
    var view: some View {
        switch self {
        case .basics:
            QuizTile(title: "Quiz: Keto Basics", message: "Warm up with foundational questions to lock in daily principles.")
        case .labels:
            QuizTile(title: "Quiz: Label Literacy", message: "Practice spotting hidden sugars and decoding nutrition panels.")
        case .electrolytes:
            QuizTile(title: "Quiz: Electrolyte Essentials", message: "Check your knowledge on hydration, sodium, and mineral needs.")
        case .fasting101:
            QuizTile(title: "Quiz: Fasting 101", message: "Gauge understanding of fasting windows, safety, and pacing.")
        }
    }
}

private struct QuizTile: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    QuizzesView()
        .environmentObject(FeatureFlagStore())
}
