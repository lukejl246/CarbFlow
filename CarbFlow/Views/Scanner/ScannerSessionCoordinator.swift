import AVFoundation
import UIKit

/// Manages AVFoundation capture session for barcode scanning with normalization and duplicate detection
final class ScannerSessionCoordinator: NSObject {
    // MARK: - Properties

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.carbflow.scanner.session")
    private let metadataOutput = AVCaptureMetadataOutput()

    /// Current video device (back camera) - needed for torch control
    private var videoDevice: AVCaptureDevice?

    private var lastDetectedCode: String?
    private var lastDetectionTime: Date?
    private let duplicateDetectionWindow: TimeInterval = 2.0
    private let pauseDurationAfterDetection: TimeInterval = 1.5

    private var isPaused = false
    private var torchEnabled = false

    /// Track session running state
    private(set) var isSessionRunning = false

    var onCodeDetected: ((String) -> Void)?
    var onError: ((ScannerError) -> Void)?

    // MARK: - Error Types

    enum ScannerError: LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case configurationFailed(String)
        case torchUnavailable
        case torchOperationFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera is not available on this device."
            case .permissionDenied:
                return "Camera permission denied."
            case .configurationFailed(let message):
                return "Failed to configure camera: \(message)"
            case .torchUnavailable:
                return "Torch is not available on this device."
            case .torchOperationFailed:
                return "Failed to toggle torch."
            }
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Session Management

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Check if session is already running
            if self.captureSession.isRunning {
                self.isSessionRunning = true
                return
            }

            // Configure session if not already configured
            if self.captureSession.inputs.isEmpty {
                self.configureSession()
            }

            self.captureSession.startRunning()
            self.isSessionRunning = true

            // Restore torch state if it was enabled
            if self.torchEnabled {
                self.restoreTorchState()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.isSessionRunning = false
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Add video input
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.cameraUnavailable)
            }
            return
        }

        // Store device reference for torch control
        self.videoDevice = videoCaptureDevice

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.configurationFailed("Failed to create video input: \(error.localizedDescription)"))
            }
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.configurationFailed("Cannot add video input to session"))
            }
            return
        }

        captureSession.addInput(videoInput)

        // Add metadata output
        guard captureSession.canAddOutput(metadataOutput) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.configurationFailed("Cannot add metadata output to session"))
            }
            return
        }

        captureSession.addOutput(metadataOutput)

        // Configure metadata types
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [
            .upce,
            .ean8,
            .ean13,
            .code128
        ]
    }

    // MARK: - Torch Control

    func setTorchEnabled(_ enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Use stored device reference if available, otherwise get default
            let device = self.videoDevice ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

            guard let device = device else {
                DispatchQueue.main.async {
                    self.onError?(.torchUnavailable)
                }
                return
            }

            guard device.hasTorch else {
                DispatchQueue.main.async {
                    self.onError?(.torchUnavailable)
                }
                return
            }

            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
                self.torchEnabled = enabled
            } catch {
                DispatchQueue.main.async {
                    self.onError?(.torchOperationFailed)
                }
            }
        }
    }

    private func restoreTorchState() {
        // Use stored device reference if available
        let device = self.videoDevice ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        guard let device = device, device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = torchEnabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Silent fail for torch restoration
        }
    }

    // MARK: - Duplicate Detection

    private func isDuplicate(_ code: String) -> Bool {
        guard let lastCode = lastDetectedCode,
              let lastTime = lastDetectionTime else {
            return false
        }

        let now = Date()
        let timeSinceLastDetection = now.timeIntervalSince(lastTime)

        return lastCode == code && timeSinceLastDetection < duplicateDetectionWindow
    }

    private func recordDetection(_ code: String) {
        lastDetectedCode = code
        lastDetectionTime = Date()
    }

    // MARK: - Auto-Pause

    private func pauseDetection() {
        isPaused = true

        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDurationAfterDetection) { [weak self] in
            self?.isPaused = false
        }
    }

    // MARK: - Barcode Normalization

    private func normalizeBarcode(_ rawCode: String, type: AVMetadataObject.ObjectType) -> String? {
        // Strip non-digits
        let digitsOnly = rawCode.filter { $0.isNumber }

        // Validate based on type
        switch type {
        case .upce:
            // UPC-E is 8 digits, expand to UPC-A (12 digits) for validation
            guard digitsOnly.count == 8 else { return nil }
            let expandedCode = expandUPCE(digitsOnly)
            return validateUPCA(expandedCode) ? expandedCode : nil

        case .ean8:
            // EAN-8 is 8 digits
            guard digitsOnly.count == 8 else { return nil }
            return validateEAN8(digitsOnly) ? digitsOnly : nil

        case .ean13:
            // EAN-13 is 13 digits
            guard digitsOnly.count == 13 else { return nil }
            return validateEAN13(digitsOnly) ? digitsOnly : nil

        case .code128:
            // Code 128 can contain non-digits, return digits only without validation
            return digitsOnly.isEmpty ? nil : digitsOnly

        default:
            return digitsOnly.isEmpty ? nil : digitsOnly
        }
    }

    // MARK: - UPC-E Expansion

    private func expandUPCE(_ upce: String) -> String {
        guard upce.count == 8 else { return upce }

        let numberSystem = String(upce.prefix(1))
        let manufacturer = String(upce.dropFirst().prefix(6))
        let checkDigit = String(upce.suffix(1))
        let lastDigit = String(manufacturer.suffix(1))

        var expanded = numberSystem

        switch lastDigit {
        case "0", "1", "2":
            expanded += String(manufacturer.prefix(2)) + lastDigit + "0000" + String(manufacturer.dropFirst(2).dropLast())
        case "3":
            expanded += String(manufacturer.prefix(3)) + "00000" + String(manufacturer.dropFirst(3).dropLast())
        case "4":
            expanded += String(manufacturer.prefix(4)) + "00000" + String(manufacturer.dropFirst(4).dropLast())
        default:
            expanded += String(manufacturer.prefix(5)) + "0000" + lastDigit
        }

        expanded += checkDigit
        return expanded
    }

    // MARK: - Checksum Validation

    private func validateUPCA(_ code: String) -> Bool {
        guard code.count == 12 else { return false }

        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 12 else { return false }

        var sum = 0
        for (index, digit) in digits.dropLast().enumerated() {
            if index % 2 == 0 {
                sum += digit * 3
            } else {
                sum += digit
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits.last
    }

    private func validateEAN13(_ code: String) -> Bool {
        guard code.count == 13 else { return false }

        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 13 else { return false }

        var sum = 0
        for (index, digit) in digits.dropLast().enumerated() {
            if index % 2 == 0 {
                sum += digit
            } else {
                sum += digit * 3
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits.last
    }

    private func validateEAN8(_ code: String) -> Bool {
        guard code.count == 8 else { return false }

        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 8 else { return false }

        var sum = 0
        for (index, digit) in digits.dropLast().enumerated() {
            if index % 2 == 0 {
                sum += digit * 3
            } else {
                sum += digit
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return checkDigit == digits.last
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerSessionCoordinator: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Ignore if paused
        guard !isPaused else { return }

        // Find first readable code object
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let rawCode = metadataObject.stringValue else {
            return
        }

        // Normalize barcode
        guard let normalizedCode = normalizeBarcode(rawCode, type: metadataObject.type) else {
            return
        }

        // Check for duplicates
        guard !isDuplicate(normalizedCode) else {
            return
        }

        // Record detection
        recordDetection(normalizedCode)

        // Pause detection temporarily
        pauseDetection()

        // Notify callback
        onCodeDetected?(normalizedCode)
    }
}

// MARK: - Preview Layer

extension ScannerSessionCoordinator {

    /// Create a preview layer for displaying camera feed
    /// - Returns: Configured AVCaptureVideoPreviewLayer
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
}

// MARK: - Authorization Helper

extension ScannerSessionCoordinator {

    /// Check camera authorization status
    static func checkCameraAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Request camera authorization
    static func requestCameraAuthorization() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }
}
