import AVFoundation
import UIKit

final class ScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    enum ScannerError: Error {
        case cameraUnavailable
        case inputUnsupported
        case outputUnsupported
    }

    private let supportedTypes: [AVMetadataObject.ObjectType] = {
        var types: [AVMetadataObject.ObjectType] = [
            .ean13,
            .ean8,
            .upce,
            .code128
        ]
        let upcA = AVMetadataObject.ObjectType(rawValue: "org.gs1.UPC.A")
        types.append(upcA)
        return types
    }()

    private let sessionQueue = DispatchQueue(label: "com.carbflow.scanner.session", qos: .userInitiated)
    private let metadataOutput = AVCaptureMetadataOutput()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let duplicateInterval: TimeInterval = 1.5
    private let pauseInterval: TimeInterval = 0.8

    let session = AVCaptureSession()

    var onCodeDetected: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var captureDevice: AVCaptureDevice?
    private var lastDetection: (code: String, date: Date)?
    private var isConfigured = false
    private var pendingTorchState: Bool?
    private var resumeTime: Date = .distantPast
    private var pauseWorkItem: DispatchWorkItem?
    private var isPaused: Bool {
        Date() < resumeTime
    }

    var hasTorch: Bool {
        captureDevice?.hasTorch == true
    }

    func startSession() {
        let requestTime = Date()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.impactFeedback.prepare()
                    self.notificationFeedback.prepare()
                }
#if DEBUG
                let elapsed = Date().timeIntervalSince(requestTime) * 1000
                print("[Scanner] startSession in \(String(format: "%.1f", elapsed)) ms")
#endif
            } catch {
#if DEBUG
                let elapsed = Date().timeIntervalSince(requestTime) * 1000
                print("[Scanner] startSession failed in \(String(format: "%.1f", elapsed)) ms: \(error.localizedDescription)")
#endif
                self.dispatchError(error)
            }
        }
    }

    func stopSession() {
        let requestTime = Date()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.pauseWorkItem?.cancel()
            self.pauseWorkItem = nil
            self.resumeTime = .distantPast
            self.session.stopRunning()
#if DEBUG
            let elapsed = Date().timeIntervalSince(requestTime) * 1000
            print("[Scanner] stopSession in \(String(format: "%.1f", elapsed)) ms")
#endif
        }
    }

    func setTorch(enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let device = strongSelf.captureDevice, device.hasTorch else {
                strongSelf.pendingTorchState = enabled
                return
            }
            strongSelf.pendingTorchState = nil
            strongSelf.applyTorch(device: device, enabled: enabled)
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ScannerError.cameraUnavailable
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw ScannerError.inputUnsupported
        }
        session.addInput(input)

        guard session.canAddOutput(metadataOutput) else {
            session.commitConfiguration()
            throw ScannerError.outputUnsupported
        }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
        let availableTypes = metadataOutput.availableMetadataObjectTypes
        let requestedTypes = supportedTypes.filter { availableTypes.contains($0) }
        metadataOutput.metadataObjectTypes = requestedTypes.isEmpty ? availableTypes : requestedTypes

        session.commitConfiguration()
        captureDevice = device
        if let pendingTorchState {
            self.pendingTorchState = nil
            applyTorch(device: device, enabled: pendingTorchState)
        }
        isConfigured = true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = metadata.stringValue,
              !payload.isEmpty else { return }

        if isPaused {
            return
        }

        guard let normalized = BarcodeNormalizer.normalize(payload) else {
            return
        }

        let now = Date()
        if let last = lastDetection,
           last.code == normalized,
           now.timeIntervalSince(last.date) < duplicateInterval {
            return
        }

        lastDetection = (normalized, now)
        applyPause()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.impactFeedback.impactOccurred()
            self.onCodeDetected?(normalized)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didDrop metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Intentionally silent; drop events are common and not actionable for the user.
    }

    private func dispatchError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.notificationFeedback.notificationOccurred(.error)
            self?.onError?(error)
        }
    }

    private func applyTorch(device: AVCaptureDevice, enabled: Bool) {
        do {
            try device.lockForConfiguration()
            if enabled {
                let level = min(AVCaptureDevice.maxAvailableTorchLevel, Float(1.0))
                try device.setTorchModeOn(level: level)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            dispatchError(error)
        }
    }

    private func applyPause() {
        resumeTime = Date().addingTimeInterval(pauseInterval)
        pauseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.resumeTime = .distantPast
        }
        pauseWorkItem = workItem
        sessionQueue.asyncAfter(deadline: .now() + pauseInterval, execute: workItem)
    }
}

private enum BarcodeNormalizer {
    static func normalize(_ raw: String) -> String? {
        let digits = raw.compactMap { $0.isWholeNumber ? String($0) : nil }.joined()
        guard !digits.isEmpty else { return nil }

        switch digits.count {
        case 8:
            return validateEAN8(digits) ? digits : nil
        case 12:
            return validateUPCA(digits) ? digits : nil
        case 13:
            guard validateEAN13(digits) else { return nil }
            if digits.hasPrefix("0") {
                let upc = String(digits.dropFirst())
                return validateUPCA(upc) ? upc : digits
            }
            return digits
        default:
            return nil
        }
    }

    private static func digits(from string: String) -> [Int]? {
        let values = string.compactMap { Int(String($0)) }
        return values.count == string.count ? values : nil
    }

    private static func validateEAN13(_ value: String) -> Bool {
        guard value.count == 13, let numbers = digits(from: value) else { return false }
        let check = numbers[12]
        var sum = 0
        for index in 0..<12 {
            sum += numbers[index] * (index.isMultiple(of: 2) ? 1 : 3)
        }
        let calculated = (10 - (sum % 10)) % 10
        return calculated == check
    }

    private static func validateUPCA(_ value: String) -> Bool {
        guard value.count == 12, let numbers = digits(from: value) else { return false }
        let check = numbers[11]
        var sum = 0
        for index in 0..<11 {
            sum += numbers[index] * (index.isMultiple(of: 2) ? 3 : 1)
        }
        let calculated = (10 - (sum % 10)) % 10
        return calculated == check
    }

    private static func validateEAN8(_ value: String) -> Bool {
        guard value.count == 8, let numbers = digits(from: value) else { return false }
        let check = numbers[7]
        var sum = 0
        for index in 0..<7 {
            sum += numbers[index] * (index.isMultiple(of: 2) ? 3 : 1)
        }
        let calculated = (10 - (sum % 10)) % 10
        return calculated == check
    }
}
