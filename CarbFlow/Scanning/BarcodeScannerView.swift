import AVFoundation
import Combine
import SwiftUI

struct BarcodeScannerView: View {
    private class ViewModel: ObservableObject {
        @Published var torchEnabled = false
        @Published var isCameraUnavailable = false
        @Published var unavailableReason: String?

        let coordinator: ScannerCoordinator
        let hasTorch: Bool

        private let onCode: (String) -> Void
        private let onError: ((Error) -> Void)?

        init(onCodeDetected: @escaping (String) -> Void, onError: ((Error) -> Void)?) {
            self.onCode = onCodeDetected
            self.onError = onError

            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            self.hasTorch = device?.hasTorch ?? false
            self.isCameraUnavailable = device == nil

            let coordinator = ScannerCoordinator()
            self.coordinator = coordinator

            coordinator.onCodeDetected = { [weak self] code in
                self?.onCode(code)
            }

            coordinator.onError = { [weak self] error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if case ScannerCoordinator.ScannerError.cameraUnavailable = error {
                        self.isCameraUnavailable = true
                        self.unavailableReason = "Camera unavailable on this device."
                    } else {
                        self.unavailableReason = error.localizedDescription
                    }
                    self.onError?(error)
                }
            }
        }

        func start() {
            #if targetEnvironment(simulator)
            isCameraUnavailable = true
            unavailableReason = "Camera not available in the simulator."
            #else
            coordinator.startSession()
            #endif
        }

        func stop() {
            coordinator.stopSession()
            setTorch(enabled: false)
        }

        func toggleTorch() {
            guard hasTorch else { return }
            torchEnabled.toggle()
            coordinator.setTorch(enabled: torchEnabled)
        }

        func setTorch(enabled: Bool) {
            guard hasTorch else { return }
            torchEnabled = enabled
            coordinator.setTorch(enabled: enabled)
        }
    }

    private struct ScannerPreview: UIViewRepresentable {
        let session: AVCaptureSession

        func makeUIView(context: Context) -> PreviewView {
            let view = PreviewView(frame: .zero)
            view.videoPreviewLayer.session = session
            view.videoPreviewLayer.videoGravity = .resizeAspectFill
            view.videoPreviewLayer.needsDisplayOnBoundsChange = true
            view.clipsToBounds = true
            return view
        }

        func updateUIView(_ uiView: PreviewView, context: Context) {}

        final class PreviewView: UIView {
            override class var layerClass: AnyClass {
                AVCaptureVideoPreviewLayer.self
            }

            var videoPreviewLayer: AVCaptureVideoPreviewLayer {
                guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                    fatalError("Expected AVCaptureVideoPreviewLayer backing layer.")
                }
                return previewLayer
            }
        }
    }

    @StateObject private var viewModel: ViewModel
    @State private var scanLineOffset: CGFloat = -0.45

    private let hintText = "Align barcode within the frame"

    init(onCodeDetected: @escaping (String) -> Void, onError: ((Error) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ViewModel(onCodeDetected: onCodeDetected, onError: onError))
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    ScannerPreview(session: viewModel.coordinator.session)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .overlay(reticleOverlay)
                        .overlay(cameraUnavailableOverlay)
                        .overlay(alignment: .topTrailing) { torchButton }
                        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
                        .frame(height: 320)

                }

                Text(hintText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .onAppear {
            viewModel.start()
            startScanAnimation()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var reticleOverlay: some View {
        GeometryReader { geometry in
            let cornerRadius: CGFloat = 12
            let inset: CGFloat = 32
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .padding(inset)
                    .accessibilityElement()
                    .accessibilityLabel("Scanning frame")
                    .accessibilityHint("Align a barcode within the frame to scan.")

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.0), Color.white.opacity(0.75), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 2)
                    .offset(y: geometry.size.height * scanLineOffset)
                    .padding(.horizontal, inset + 8)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: scanLineOffset)
            }
        }
    }

    @ViewBuilder
    private var cameraUnavailableOverlay: some View {
        if viewModel.isCameraUnavailable {
            Color.black.opacity(0.45)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                        Text(viewModel.unavailableReason ?? "Camera unavailable.")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                )
        }
    }

    @ViewBuilder
    private var torchButton: some View {
        if viewModel.hasTorch && !viewModel.isCameraUnavailable {
            Button(action: viewModel.toggleTorch) {
                Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.85))
                    )
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel(viewModel.torchEnabled ? "Turn torch off" : "Turn torch on")
            .accessibilityHint("Improves barcode visibility in low light.")
        }
    }

    private func startScanAnimation() {
        scanLineOffset = -0.45
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            scanLineOffset = 0.45
        }
    }
}
