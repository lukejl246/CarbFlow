import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol CFErrorReportingDestination {
    func send(level: CFErrorReportingRouter.Level,
              message: String,
              code: String?,
              context: [String: Any],
              breadcrumbs: [[String: Any]],
              timestamp: Date)
}

struct ConsoleErrorReportingDestination: CFErrorReportingDestination {
    func send(level: CFErrorReportingRouter.Level,
              message: String,
              code: String?,
              context: [String: Any],
              breadcrumbs: [[String: Any]],
              timestamp: Date) {
#if DEBUG
        let codeSuffix = code.map { " code=\($0)" } ?? ""
        let contextSummary = context.keys.sorted().joined(separator: ",")
        let breadcrumbSummary = breadcrumbs.compactMap { $0["label"] as? String }.joined(separator: " → ")
        let timestampValue = Int(timestamp.timeIntervalSince1970)
        print("[CFErrorReporter] level=\(level.rawValue) message=\(message)\(codeSuffix) ts=\(timestampValue) context_keys=[\(contextSummary)] breadcrumbs=[\(breadcrumbSummary)]")
#endif
    }
}

final class CFErrorReportingRouter {
    enum Level: String {
        case error
        case warning
        case info
    }

    static let shared = CFErrorReportingRouter()

    var destination: CFErrorReportingDestination
    var enabled: Bool

    private let rateLimiter: CFRateLimiter
    private let queue = DispatchQueue(label: "com.carbflow.error-reporting")
    private(set) var breadcrumbPayloads: [[String: Any]]
    private let buildInfo: [String: String]
    private let deviceInfo: [String: String]

    private init(destination: CFErrorReportingDestination = ConsoleErrorReportingDestination(),
                 enabled: Bool = {
#if DEBUG
        true
#else
        false
#endif
                 }(),
                 rateLimiter: CFRateLimiter = CFRateLimiter(maxEvents: 8, interval: 15)) {
        self.destination = destination
        self.enabled = enabled
        self.rateLimiter = rateLimiter
        self.breadcrumbPayloads = []

        let appVersion = AppVersion.current
        self.buildInfo = [
            "marketing": appVersion.marketing,
            "build": appVersion.build
        ]

#if canImport(UIKit)
        let device = UIDevice.current
        self.deviceInfo = [
            "model": device.model,
            "system": device.systemName,
            "version": device.systemVersion
        ]
#else
        let process = ProcessInfo.processInfo
        self.deviceInfo = [
            "model": process.hostName,
            "system": process.operatingSystemVersionString
        ]
#endif
    }

    func updateBreadcrumbs(_ breadcrumbs: [[String: Any]]) {
        queue.async { [weak self] in
            self?.breadcrumbPayloads = breadcrumbs
        }
    }

    func report(level: Level,
                message: String,
                code: String?,
                context: [String: Any]) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.enabled else { return }
            let now = Date()
            guard self.rateLimiter.allow(at: now) else { return }

            var sanitizedContext = cf_redactContext(context)
            sanitizedContext["build"] = self.buildInfo
            sanitizedContext["device"] = self.deviceInfo

            let breadcrumbs = self.breadcrumbPayloads
            self.destination.send(
                level: level,
                message: message,
                code: code,
                context: sanitizedContext,
                breadcrumbs: breadcrumbs,
                timestamp: now
            )
        }
    }
}

private final class CFRateLimiter {
    private let maxEvents: Int
    private let interval: TimeInterval
    private var timestamps: [Date] = []

    init(maxEvents: Int, interval: TimeInterval) {
        self.maxEvents = maxEvents
        self.interval = interval
    }

    func allow(at date: Date) -> Bool {
        timestamps = timestamps.filter { date.timeIntervalSince($0) < interval }
        guard timestamps.count < maxEvents else { return false }
        timestamps.append(date)
        return true
    }
}

func cf_reportError(message: String,
                    code: String? = nil,
                    context: [String: Any] = [:]) {
    CFErrorReportingRouter.shared.report(level: .error, message: message, code: code, context: context)
}

func cf_reportWarning(message: String,
                      context: [String: Any] = [:]) {
    CFErrorReportingRouter.shared.report(level: .warning, message: message, code: nil, context: context)
}

func cf_reportInfo(message: String,
                   context: [String: Any] = [:]) {
    CFErrorReportingRouter.shared.report(level: .info, message: message, code: nil, context: context)
}
