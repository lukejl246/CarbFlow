import Foundation

protocol AnalyticsDestination {
    func send(name: String, params: [String: Any])
}

struct ConsoleAnalyticsDestination: AnalyticsDestination {
    func send(name: String, params: [String: Any]) {
#if DEBUG
        let payload = params.map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")
        print("[Analytics] \(name) { \(payload) }")
#endif
    }
}

enum AnalyticsRouter {
    private static var currentDestination: AnalyticsDestination = ConsoleAnalyticsDestination()

    static var enabled = true

    static var destination: AnalyticsDestination {
        get { currentDestination }
        set { currentDestination = newValue }
    }
}

func cf_logEvent(_ name: String, _ params: [String: Any]) {
    guard AnalyticsRouter.enabled else { return }
    AnalyticsRouter.destination.send(name: name, params: params)
}
