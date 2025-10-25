import SwiftUI

struct FastingView: View {
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
        .navigationTitle("Fasting")
        .animation(.easeInOut(duration: 0.25), value: flags.fastingEnabled)
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(.teal.opacity(0.7))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Fasting coming soon")
                        .font(.headline)
                    Text("Track fasting windows, gentle streaks, and reflective notes right here. Not medical advice.")
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
    FastingView()
        .environmentObject(FeatureFlagStore())
}
