import SwiftUI

struct ProgrammeView: View {
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
        .navigationTitle("Programme")
        .animation(.easeInOut(duration: 0.25), value: flags.programmeEnabled)
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.orange.opacity(0.7))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("30-Day Programme coming soon")
                        .font(.headline)
                    Text("A guided, day-by-day plan with unlocks and gentle milestones will live here.")
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
    ProgrammeView()
        .environmentObject(FeatureFlagStore())
}
