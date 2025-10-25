import SwiftUI

struct DashboardSleepTile: View {
    @State private var isVisible = false

    var body: some View {
        TileCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep")
                    .font(.headline)
                Text("Sleep coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Expect nightly duration summaries with recovery pointers once ready.")
                    .font(.footnote)
            }
        }
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

private struct TileCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
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
