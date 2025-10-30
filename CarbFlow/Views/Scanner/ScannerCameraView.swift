import SwiftUI
import AVFoundation
import Combine

struct ScannerCameraView: View {
    let onCodeDetected: (String) -> Void

    @StateObject private var cameraSession = CameraScannerSession()
    @State private var isTorchOn = false
    @State private var showScanLine = true

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            if cameraSession.isCameraAvailable {
                cameraPreview
                scannerOverlay
                torchButton
            } else {
                unavailableView
            }
        }
        .onAppear {
            cameraSession.onCodeDetected = onCodeDetected
            cameraSession.startSession()
        }
        .onDisappear {
            cameraSession.stopSession()
        }
    }

    private var cameraPreview: some View {
        CameraPreviewView(session: cameraSession.captureSession)
            .ignoresSafeArea()
    }

    private var scannerOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            viewfinderFrame

            Text("Align barcode within frame")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var viewfinderFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .frame(height: 320)

            if showScanLine {
                scanLine
            }
        }
    }

    private var scanLine: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0),
                            Color.accentColor.opacity(0.8),
                            Color.accentColor.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 2)
                .offset(y: scanLineOffset(in: geometry.size.height))
        }
        .frame(height: 320)
        .onAppear {
            startScanLineAnimation()
        }
    }

    @State private var scanLinePosition: CGFloat = 0

    private func scanLineOffset(in height: CGFloat) -> CGFloat {
        scanLinePosition * height
    }

    private func startScanLineAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            scanLinePosition = 1.0
        }
    }

    private var torchButton: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    toggleTorch()
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title3)
                        .foregroundColor(isTorchOn ? .accentColor : .primary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 60)

            Spacer()
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera unavailable")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Camera access is required to scan barcodes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func toggleTorch() {
        isTorchOn.toggle()
        cameraSession.toggleTorch(on: isTorchOn)
    }
}

// MARK: - Camera Preview

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Scanner Session

@MainActor
private class CameraScannerSession: NSObject, ObservableObject {
    @Published var isCameraAvailable = true

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.carbflow.scanner.session")
    private var videoDevice: AVCaptureDevice?

    var onCodeDetected: ((String) -> Void)?

    private var lastDetectionTime: Date?
    private let detectionCooldown: TimeInterval = 1.5

    override init() {
        super.init()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // Setup video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.videoDevice = videoDevice

            guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addInput(videoInput)

            // Setup metadata output for barcode detection
            let metadataOutput = AVCaptureMetadataOutput()

            guard self.captureSession.canAddOutput(metadataOutput) else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

            // Support common barcode types
            let supportedTypes: [AVMetadataObject.ObjectType] = [
                .upce,
                .ean8,
                .ean13,
                .code128
            ]

            metadataOutput.metadataObjectTypes = supportedTypes.filter {
                metadataOutput.availableMetadataObjectTypes.contains($0)
            }

            self.captureSession.commitConfiguration()
        }
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func toggleTorch(on: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("[Scanner] Failed to toggle torch: \(error)")
            }
        }
    }
}

// MARK: - Metadata Delegate

extension CameraScannerSession: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let code = readableObject.stringValue else {
            return
        }

        Task { @MainActor in
            handleDetectedCode(code)
        }
    }

    @MainActor
    private func handleDetectedCode(_ code: String) {
        // Prevent duplicate detections
        let now = Date()
        if let lastTime = lastDetectionTime,
           now.timeIntervalSince(lastTime) < detectionCooldown {
            return
        }

        lastDetectionTime = now

        // Trigger haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Notify delegate
        onCodeDetected?(code)

        // Log detection
        cf_logEvent("barcode-detected", ["code": code, "ts": now.timeIntervalSince1970])
    }
}
