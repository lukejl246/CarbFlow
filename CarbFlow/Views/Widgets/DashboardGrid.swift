import SwiftUI

struct DashboardItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let tint: Color
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        tint: Color = .accentColor,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
        self.action = action
    }
}

struct DashboardGrid: View {
    let title: String?
    let items: [DashboardItem]
    @Environment(\.sizeCategory) private var sizeCategory

    private var minimumWidth: CGFloat {
        sizeCategory.isAccessibilityCategory ? 320 : 172
    }

    private var tileHeight: CGFloat {
        sizeCategory.isAccessibilityCategory ? 148 : 120
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: minimumWidth, maximum: 240), spacing: 16)
        ]
    }

    init(title: String? = nil, items: [DashboardItem]) {
        self.title = title
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    WidgetCard(
                        icon: item.icon,
                        title: item.title,
                        value: item.value,
                        subtitle: item.subtitle,
                        tint: item.tint,
                        action: item.action,
                        fixedHeight: tileHeight
                    )
                    .frame(
                        minHeight: tileHeight,
                        idealHeight: tileHeight,
                        maxHeight: tileHeight,
                        alignment: .top
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}

#Preview {
    ScrollView {
        DashboardGrid(
            items: [
                DashboardItem(
                    icon: "bolt.fill",
                    title: "Energy",
                    value: "High",
                    subtitle: "Great focus today",
                    tint: .orange,
                    action: { print("Energy tapped") }
                ),
                DashboardItem(
                    icon: "drop.fill",
                    title: "Hydration",
                    value: "48 oz",
                    subtitle: "Keep sipping",
                    tint: .blue
                ),
                DashboardItem(
                    icon: "heart.fill",
                    title: "Resting HR",
                    value: "58 bpm",
                    tint: .red
                ),
                DashboardItem(
                    icon: "flame.fill",
                    title: "Ketones",
                    value: "1.7 mmol",
                    subtitle: "Glucose steady",
                    tint: .pink
                )
            ]
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
