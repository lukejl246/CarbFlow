import SwiftUI
import AVFoundation

/// Permission UI for camera access with status-aware button hierarchy
struct ScannerPermissionView: View {
    let onPermissionGranted: () -> Void
    let onEnterManually: () -> Void

    @State private var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Light grey canvas
            Color(.systemGray6)
                .ignoresSafeArea()

            // Permission card
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.accentColor)

                // Text content
                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("CarbFlow needs camera access to scan barcodes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                VStack(spacing: 12) {
                    if authorizationStatus == .denied || authorizationStatus == .restricted {
                        // Show "Open Settings" button when previously denied
                        Button {
                            openSettings()
                        } label: {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .cornerRadius(14)
                        }
                        .accessibilityHint("Opens iOS Settings to enable camera access for CarbFlow")
                    } else {
                        // Show "Enable Camera" button for not determined
                        Button {
                            requestCameraPermission()
                        } label: {
                            Text("Enable Camera")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .cornerRadius(14)
                        }
                        .accessibilityHint("Requests camera permission for barcode scanning")
                    }

                    // Secondary button - Enter Manually
                    Button {
                        onEnterManually()
                    } label: {
                        Text("Enter Manually")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Dismiss scanner and enter barcode manually")
                }
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(24)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            checkAuthorizationStatus()
            withAnimation(.easeInOut(duration: 0.25)) {
                showContent = true
            }
        }
        .onChange(of: authorizationStatus) { _, newStatus in
            if newStatus == .authorized {
                // Auto-dismiss when permission granted
                withAnimation(.easeInOut(duration: 0.25)) {
                    showContent = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onPermissionGranted()
                }
            }
        }
    }

    // MARK: - Permission Handling

    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Preview

#Preview("Not Determined") {
    ScannerPermissionView(
        onPermissionGranted: {},
        onEnterManually: {}
    )
}

#Preview("Denied") {
    // Note: In preview, status will show as .notDetermined
    // This preview demonstrates the UI structure
    ScannerPermissionView(
        onPermissionGranted: {},
        onEnterManually: {}
    )
}
