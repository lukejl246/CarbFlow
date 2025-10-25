import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var flags: FeatureFlagStore

    private var visibleTiles: [DashboardTile] {
        var tiles: [DashboardTile] = []

        if flags.dashboardSummaryEnabled {
            tiles.append(.summary)
        }
        if flags.dashboardTrendsEnabled {
            tiles.append(.trends)
        }
        if flags.dashboardStreaksEnabled {
            tiles.append(.streaks)
        }
        if flags.dashboardMacrosEnabled {
            tiles.append(.macros)
        }
        if flags.dashboardHydrationEnabled {
            tiles.append(.hydration)
        }
        if flags.dashboardSleepEnabled {
            tiles.append(.sleep)
        }
        if flags.dashboardReadinessEnabled {
            tiles.append(.readiness)
        }

        return tiles
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if visibleTiles.isEmpty {
                    DashboardPlaceholderTile()
                } else {
                    ForEach(visibleTiles) { tile in
                        tile.view
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: visibleTiles)
    }
}

private enum DashboardTile: String, Identifiable, CaseIterable {
    case summary
    case trends
    case streaks
    case macros
    case hydration
    case sleep
    case readiness

    var id: String { rawValue }

    @ViewBuilder
    var view: some View {
        switch self {
        case .summary:
            DashboardSummaryTile()
        case .trends:
            DashboardTrendsTile()
        case .streaks:
            DashboardStreaksTile()
        case .macros:
            DashboardMacrosTile()
        case .hydration:
            DashboardHydrationTile()
        case .sleep:
            DashboardSleepTile()
        case .readiness:
            DashboardReadinessTile()
        }
    }
}

private struct DashboardPlaceholderTile: View {
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard coming soon")
                .font(.headline)
            Text("We’re preparing tailored insights. Enable tiles from Developer Flags to preview in-progress cards.")
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
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        .accessibilityElement(children: .contain)
    }
}
#Preview {
    let flags = FeatureFlagStore()
    DashboardView()
        .environmentObject(flags)
}
