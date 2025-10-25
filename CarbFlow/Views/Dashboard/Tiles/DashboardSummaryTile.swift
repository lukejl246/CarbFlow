import SwiftUI

struct DashboardSummaryTile: View {
    @State private var isVisible = false

    var body: some View {
        TileCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Summary")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("21")
                            .font(.title2)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lesson completion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("70%")
                            .font(.title3)
                            .bold()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Next focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Review Day 21 recipe prep before tomorrow.")
                        .font(.subheadline)
                }
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
