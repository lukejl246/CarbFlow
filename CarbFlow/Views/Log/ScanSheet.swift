import SwiftUI
import UIKit

struct ScanSheet: View {
    let onScanned: (String) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var cameraStatus: ScanAuthorizationStatus = .notDetermined
    @State private var showPermissionCard = false

    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeScannerView(
                    onCodeDetected: { code in
                        onScanned(code)
                        closeSheet()
                    },
                    onError: { error in
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                )
                .opacity(showPermissionCard ? 0.1 : 1.0)

                if showPermissionCard {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .opacity(0.9)
                        .transition(.opacity)
                    permissionHelpCard
                        .padding(24)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        closeSheet()
                    }
                    .accessibilityLabel("Close scanner")
                    .accessibilityHint("Dismisses the barcode scanner.")
                }
            }
            .alert("Scanner Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    showingError = false
                    closeSheet()
                }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingError)
        .animation(.easeInOut(duration: 0.25), value: showPermissionCard)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            notificationFeedback.prepare()
            await evaluateCameraStatus()
        }
        .onChange(of: cameraStatus) { _, newValue in
            handleCameraStatusChange(newValue)
        }
    }

    private func closeSheet() {
        onClose()
        dismiss()
    }

    private var permissionHelpCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.slash")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Camera access is off")
                    .font(.title3.weight(.semibold))
                Text("Enable camera permissions in Settings to scan barcodes with CarbFlow.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    openSettings()
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens iOS Settings to enable camera access for CarbFlow.")

                Button {
                    closeSheet()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss the scanner without changing camera permissions.")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 20, y: 10)
        )
        .accessibilityElement(children: .contain)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleCameraStatusChange(_ status: ScanAuthorizationStatus) {
        switch status {
        case .authorized:
            if showPermissionCard {
                showPermissionCard = false
            }
        case .denied, .restricted:
            showPermissionCard = true
            notificationFeedback.notificationOccurred(.error)
        case .notDetermined:
            break
        }
    }

    private func evaluateCameraStatus() async {
        let status = await ScanPermissions.checkCameraAuthorization()
        await MainActor.run {
            cameraStatus = status
            if status == .notDetermined {
                Task {
                    let requested = await ScanPermissions.requestCameraAuthorization()
                    await MainActor.run {
                        cameraStatus = requested
                    }
                }
            } else if status == .denied || status == .restricted {
                showPermissionCard = true
            }
        }
    }
}

#Preview {
    ScanSheet(onScanned: { _ in }, onClose: { })
}
