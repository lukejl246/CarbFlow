import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum Links {
    static let supportEmail = "support@carbflow.app"
    static let privacyURL = "https://carbflow.app/privacy"
    static let termsURL = "https://carbflow.app/terms"

    static func supportMailURL(subject: String = "CarbFlow Help",
                               additionalBody: String = "") -> URL? {
        var bodyLines: [String] = [
            "Hello CarbFlow team,",
            "",
            "App Version: \(AppVersion.current.marketing) (\(AppVersion.current.build))"
        ]

#if canImport(UIKit)
        let device = UIDevice.current
        bodyLines.append("Device: \(device.model)")
        bodyLines.append("System: \(device.systemName) \(device.systemVersion)")
#else
        let process = ProcessInfo.processInfo
        bodyLines.append("Device: \(process.hostName)")
        bodyLines.append("System: \(process.operatingSystemVersionString)")
#endif

        if !additionalBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bodyLines.append("")
            bodyLines.append(additionalBody)
        }

        bodyLines.append("")
        bodyLines.append("Describe your question here.")

        let body = bodyLines.joined(separator: "\n")

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        return components.url
    }

    static func openSupportMail(additionalBody: String = "",
                                onFailure: (() -> Void)? = nil) {
        guard let url = supportMailURL(additionalBody: additionalBody) else {
            onFailure?()
            return
        }
#if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                onFailure?()
            }
        }
#else
        onFailure?()
#endif
    }
}
