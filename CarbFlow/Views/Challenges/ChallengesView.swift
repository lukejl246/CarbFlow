import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var flags: FeatureFlagStore
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if visibleCards.isEmpty {
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
                } else {
                    ForEach(visibleCards) { card in
                        card.view
                            .frame(minHeight: 120, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Challenges")
        .animation(.easeInOut(duration: 0.25), value: flags.challengesEnabled)
        .animation(.easeInOut(duration: 0.25), value: visibleCards)
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "flag")
                    .font(.title3)
                    .foregroundStyle(.pink.opacity(0.7))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Challenges coming soon")
                        .font(.headline)
                    Text("Look forward to optional mini-challenges and gentle milestones to reinforce habits.")
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

    private var visibleCards: [ChallengeCard] {
        var cards: [ChallengeCard] = []
        if flags.challengeElectrolytes7dEnabled { cards.append(.electrolytes7d) }
        if flags.challengeHydration7dEnabled { cards.append(.hydration7d) }
        if flags.challengeSteps7dEnabled { cards.append(.steps7d) }
        if flags.challengeNoSugar7dEnabled { cards.append(.noSugar7d) }
        return cards
    }
}

private enum ChallengeCard: String, Identifiable, CaseIterable {
    case electrolytes7d
    case hydration7d
    case steps7d
    case noSugar7d

    var id: String { rawValue }

    @ViewBuilder
    var view: some View {
        switch self {
        case .electrolytes7d:
            ChallengeTile(
                title: "7-Day Electrolyte Boost",
                message: "Track sodium, potassium, and magnesium each day to support energy."
            )
        case .hydration7d:
            ChallengeTile(
                title: "7-Day Hydration Reset",
                message: "Hit your hydration target daily and note how you feel."
            )
        case .steps7d:
            ChallengeTile(
                title: "7-Day Steps Momentum",
                message: "Aim for your personalised step goal each day and celebrate streaks."
            )
        case .noSugar7d:
            ChallengeTile(
                title: "7-Day No Added Sugar",
                message: "Skip added sugars and keep a quick log of swaps you enjoyed."
            )
        }
    }
}

private struct ChallengeTile: View {
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
    ChallengesView()
        .environmentObject(FeatureFlagStore())
}
