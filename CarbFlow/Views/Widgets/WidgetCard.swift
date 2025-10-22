import SwiftUI

struct WidgetCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let tint: Color
    let action: (() -> Void)?
    let fixedHeight: CGFloat?

    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        tint: Color = .accentColor,
        action: (() -> Void)? = nil,
        fixedHeight: CGFloat? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
        self.action = action
        self.fixedHeight = fixedHeight
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var content: some View {
        if let fixedHeight {
            cardBody
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(
                    minHeight: fixedHeight,
                    idealHeight: fixedHeight,
                    maxHeight: fixedHeight,
                    alignment: .top
                )
        } else {
            cardBody
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack {
                iconPill
                    .layoutPriority(0.1)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(.quaternaryLabel), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }

    private var iconPill: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.18))
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 28, height: 28)
    }
}

#Preview("Interactive card") {
    WidgetCard(
        icon: "bolt.fill",
        title: "Energy",
        value: "Steady",
        subtitle: "Feeling great today",
        tint: .orange,
        action: { print("Tapped energy card") }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Static card") {
    WidgetCard(
        icon: "drop.fill",
        title: "Hydration",
        value: "64 oz",
        subtitle: "Goal met",
        tint: .blue
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
