import Foundation

struct WhatsNewItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String?
}

struct WhatsNewPayload {
    let versionKey: String
    let headline: String
    let items: [WhatsNewItem]
    let ctaTitle: String
}

enum WhatsNewCatalog {
    static func payloadForCurrentVersion() -> WhatsNewPayload {
        let items: [WhatsNewItem] = [
            WhatsNewItem(
                id: "improved-tracking",
                title: "Faster meal tracking",
                subtitle: "Log meals with fewer taps thanks to refreshed shortcuts.",
                systemImage: "bolt"
            ),
            WhatsNewItem(
                id: "insights-dashboard",
                title: "Insights dashboard",
                subtitle: "Review daily trends with a redesigned summary card.",
                systemImage: "chart.bar"
            ),
            WhatsNewItem(
                id: "reminder-tuning",
                title: "Flexible reminders",
                subtitle: "Set new quiet hours and personalize notification timing.",
                systemImage: "bell.badge"
            ),
            WhatsNewItem(
                id: "sync-updates",
                title: "Background sync",
                subtitle: "Data stays current even when the app is minimized.",
                systemImage: "arrow.triangle.2.circlepath"
            )
        ]

        return WhatsNewPayload(
            versionKey: AppVersion.versionKey(),
            headline: "What's new in CarbFlow",
            items: items,
            ctaTitle: "Let's go"
        )
    }
}
