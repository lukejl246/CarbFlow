import Foundation
import CoreFoundation

struct CFRedactor {
    static func sanitize(context: [String: Any]) -> [String: Any] {
        sanitizeValue(context, depth: 0) as? [String: Any] ?? [:]
    }

    private static func sanitizeValue(_ value: Any, depth: Int) -> Any? {
        if depth > 3 { return nil }

        switch value {
        case let dict as [String: Any]:
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if isSensitive(key: key) { continue }
                if let sanitized = sanitizeValue(val, depth: depth + 1) {
                    result[key] = sanitized
                }
            }
            return result
        case let array as [Any]:
            guard depth < 3 else { return nil }
            let sanitized = array.compactMap { sanitizeValue($0, depth: depth + 1) }
            return Array(sanitized.prefix(20))
        case let str as String:
            return String(str.prefix(256))
        case let num as NSNumber:
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return num.boolValue
            }
            if CFNumberIsFloatType(num) {
                return num.doubleValue
            } else {
                return num.intValue
            }
        case let date as Date:
            return date.timeIntervalSince1970
        case let bool as Bool:
            return bool
        default:
            return nil
        }
    }

    private static func isSensitive(key: String) -> Bool {
        let lower = key.lowercased()
        return lower.contains("token") ||
            lower.contains("email") ||
            lower.contains("name") ||
            lower.contains("note") ||
            lower.contains("authorization") ||
            lower.contains("password")
    }
}

func cf_redactContext(_ context: [String: Any]) -> [String: Any] {
    CFRedactor.sanitize(context: context)
}
