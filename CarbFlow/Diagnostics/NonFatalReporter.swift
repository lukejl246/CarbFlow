import Foundation

protocol ErrorSink {
    func send(name: String, message: String, context: [String: String])
}

struct NoOpErrorSink: ErrorSink {
    func send(name: String, message: String, context: [String: String]) { }
}

enum NonFatalReporter {
    private static let queue = DispatchQueue(label: "com.carbflow.diagnostics.nonfatal", qos: .utility)
    private static var sink: ErrorSink = NoOpErrorSink()
    private static var lastReportTimestamps: [String: Date] = [:]
    private static let rateLimitInterval: TimeInterval = 60
    private static let maxLogBytes: Int = 200_000
    private static let logURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let directory = caches.appendingPathComponent("Diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("nonfatal.log")
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func configure(sink newSink: ErrorSink = NoOpErrorSink()) {
        queue.sync {
            sink = newSink
        }
    }

    static func report(_ error: Error, context: [String: String] = [:], file: String = #fileID, line: Int = #line) {
        queue.async {
            let info = ErrorInfo(error: error, context: context, file: file, line: line)
            guard shouldReport(info: info) else { return }
            storeTimestamp(for: info)
            logToConsole(info)
            logToFile(info)
            emitAnalytics(info)
            sink.send(name: info.name, message: info.message, context: info.context)
        }
    }

    static func reportNetwork(_ error: Error, url: URL?, statusCode: Int?, context: [String: String] = [:]) {
        var ctx = context
        ctx["category"] = "network"
        if let url { ctx["url"] = url.absoluteString }
        if let statusCode { ctx["status_code"] = String(statusCode) }
        report(error, context: ctx)
    }

    static func reportParsing(_ error: Error, payloadDescription: String, context: [String: String] = [:]) {
        var ctx = context
        ctx["category"] = "parsing"
        ctx["payload"] = payloadDescription
        report(error, context: ctx)
    }

    static func reportCameraDenied(context: [String: String] = [:]) {
        var ctx = context
        ctx["category"] = "camera"
        let error = NamedError(name: "camera_denied", message: "Camera permission denied by user.")
        report(error, context: ctx)
    }

    private static func shouldReport(info: ErrorInfo) -> Bool {
        if let last = lastReportTimestamps[info.rateKey],
           Date().timeIntervalSince(last) < rateLimitInterval {
            return false
        }
        return true
    }

    private static func storeTimestamp(for info: ErrorInfo) {
        lastReportTimestamps[info.rateKey] = Date()
    }

    private static func logToConsole(_ info: ErrorInfo) {
        print("[NonFatal] \(info.timestamp) \(info.name): \(info.message) \(info.context)")
    }

    private static func logToFile(_ info: ErrorInfo) {
        let line = "\(info.timestamp) | \(info.name) | \(info.message) | \(info.context)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }

        trimIfNeeded()
    }

    private static func trimIfNeeded() {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
            let size = attributes[.size] as? NSNumber,
            size.intValue > maxLogBytes
        else { return }

        guard let data = try? Data(contentsOf: logURL) else { return }
        let trimmed = data.suffix(maxLogBytes / 2)
        try? trimmed.write(to: logURL, options: .atomic)
    }

    private static func emitAnalytics(_ info: ErrorInfo) {
        cf_logEvent("error-nonfatal", ["name": info.name] as [String: Any])
    }
}

private struct ErrorInfo {
    let name: String
    let message: String
    let context: [String: String]
    let timestamp: String

    var rateKey: String { "\(name)|\(message)" }

    init(error: Error, context: [String: String], file: String, line: Int) {
        let baseName: String
        let resolvedMessage: String
        if let named = error as? NonFatalNamedError {
            baseName = named.nonFatalName
            resolvedMessage = named.nonFatalMessage
        } else {
            baseName = String(describing: type(of: error))
            resolvedMessage = error.localizedDescription
        }

        self.name = baseName.isEmpty ? "nonfatal_error" : baseName
        self.message = resolvedMessage
        self.timestamp = NonFatalReporter.isoFormatter.string(from: Date())

        var merged = Self.sanitize(context: context)
        merged["source"] = file
        merged["line"] = String(line)
        self.context = merged
    }

    private static func sanitize(context: [String: String]) -> [String: String] {
        let blockedKeys = ["token", "auth", "password", "email"]
        var output: [String: String] = [:]
        for (key, value) in context {
            guard !blockedKeys.contains(where: { key.localizedCaseInsensitiveContains($0) }) else { continue }
            if output.count >= 12 { break }
            output[key] = value.safelyLimited(to: 128)
        }
        return output
    }
}

private protocol NonFatalNamedError {
    var nonFatalName: String { get }
    var nonFatalMessage: String { get }
}

private struct NamedError: Error, NonFatalNamedError {
    let nonFatalName: String
    let nonFatalMessage: String

    init(name: String, message: String) {
        self.nonFatalName = name
        self.nonFatalMessage = message
    }
}

private extension String {
    func safelyLimited(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let endIndex = index(startIndex, offsetBy: maxLength)
        return String(self[..<endIndex])
    }
}
