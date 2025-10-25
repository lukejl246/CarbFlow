import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var flags: FeatureFlagStore
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Coach")
        .animation(.easeInOut(duration: 0.25), value: flags.coachEnabled)
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.fill.questionmark")
                    .font(.title3)
                    .foregroundStyle(.blue.opacity(0.7))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coach coming soon")
                        .font(.headline)
                    // TODO(Phase 1): Add lightweight tips library and day-by-day nudges. Keep copy neutral. [Add refs]
                    // TODO(Phase 1): Personalisation using on-device signals (e.g. streaks, recent logs).
                    // TODO(Phase 2): Consider chat-style guidance; log messages locally; add moderation guardrails.
                    // TODO(Phase 2+): A/B test tone/microcopy with additional sub-flags (coach_tone_a, coach_tone_b).
                    // Not medical advice.
                    Text("Look forward to gentle tips, nudges, and guidance to support your low-carb habits.")
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

#Preview {
    CoachView()
        .environmentObject(FeatureFlagStore())
}
