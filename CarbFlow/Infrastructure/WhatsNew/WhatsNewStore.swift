import Combine
import Foundation

@MainActor
final class WhatsNewStore: ObservableObject {
    @Published var shouldPresent: Bool
    let payload: WhatsNewPayload

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let payload = WhatsNewCatalog.payloadForCurrentVersion()
        self.payload = payload

        let lastSeenVersion = userDefaults.string(forKey: CFKeys.whatsNewLastSeen)
        self.shouldPresent = lastSeenVersion != payload.versionKey
    }

    func markSeen() {
        userDefaults.set(payload.versionKey, forKey: CFKeys.whatsNewLastSeen)
        shouldPresent = false
        cf_logEvent("whatsnew_dismiss", ["version": payload.versionKey])
    }
}
