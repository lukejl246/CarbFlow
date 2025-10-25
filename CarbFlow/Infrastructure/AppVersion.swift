import Foundation

struct AppVersion {
    let marketing: String
    let build: String

    static let current: AppVersion = {
        let bundle = Bundle.main
        let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return AppVersion(marketing: marketingVersion, build: buildVersion)
    }()

    static func marketingVersion() -> String {
        current.marketing
    }

    static func versionKey() -> String {
        "\(current.marketing)-\(current.build)"
    }
}

enum CFKeys {
    static let whatsNewLastSeen = "cf_whatsnew_last_seen_version"
}
