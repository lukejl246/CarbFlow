import AVFoundation
import Foundation

enum ScanAuthorizationStatus {
    case authorized
    case denied
    case restricted
    case notDetermined

    fileprivate init(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .denied
        }
    }

    fileprivate var description: String {
        switch self {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        }
    }
}

enum ScanPermissions {
    static func checkCameraAuthorization() async -> ScanAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return ScanAuthorizationStatus(status)
    }

    static func requestCameraAuthorization() async -> ScanAuthorizationStatus {
        let initial = AVCaptureDevice.authorizationStatus(for: .video)
        guard initial == .notDetermined else {
            return ScanAuthorizationStatus(initial)
        }

        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }

        let final: ScanAuthorizationStatus = granted ? .authorized : .denied
        logStatusChange(from: ScanAuthorizationStatus(initial), to: final)
        return final
    }

    private static func logStatusChange(from oldValue: ScanAuthorizationStatus, to newValue: ScanAuthorizationStatus) {
        guard oldValue != newValue else { return }
        #if DEBUG
        print("[ScanPermissions] Camera authorization changed \(oldValue.description) -> \(newValue.description)")
        #endif
        cf_logEvent("scan-permission-status", ["previous": oldValue.description, "current": newValue.description])
    }
}
