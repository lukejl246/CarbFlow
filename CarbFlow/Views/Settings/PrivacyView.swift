import SwiftUI

/// Offline behaviour: all actions run locally, storing exports in caches and purging Core Data/UserDefaults without contacting remote services.

struct PrivacyView: View {
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false

    @State private var showDeleteSheet = false
    @State private var deleteConfirmationText = ""
    @State private var isDeleting = false
    @State private var deletionErrorMessage: String?
    @State private var showDeletionError = false
    @State private var showDeletionComplete = false
    @State private var hasLoggedAppear = false

    private let exportService = DataExportService()
    private let purgeService = DataPurgeService()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                card
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet, onDismiss: { exportURL = nil }) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showDeleteSheet) {
            deleteConfirmationSheet
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "We couldn't finish the export. Please try again.")
        }
        .alert("Delete failed", isPresented: $showDeletionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deletionErrorMessage ?? "We couldn't finish deleting your data. Please try again.")
        }
        .alert("Data deleted", isPresented: $showDeletionComplete) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All CarbFlow data has been cleared from this device. You can close and reopen the app to start fresh.")
        }
        .onAppear {
            if !hasLoggedAppear {
                cf_logEvent("privacy-open", ["ts": Date().timeIntervalSince1970])
                hasLoggedAppear = true
            }
        }
        .onDisappear {
            cf_logEvent("privacy-close", ["ts": Date().timeIntervalSince1970])
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your data stays yours")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    bullet(text: "No ads.")
                    bullet(text: "No data selling.")
                    bullet(text: "Works offline.")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanner policy")
                        .font(.headline)
                    Text("Scanner stays free. No ads. No data selling.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("CarbFlow helps you track privately on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Not medical advice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            VStack(spacing: 16) {
                Button {
                    handleExport()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(isExporting ? "Preparing export..." : "Export my data")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
                .accessibilityLabel("Export my data")
                .accessibilityHint("Creates a JSON file you can save or share.")

                Button {
                    deleteConfirmationText = ""
                    showDeleteSheet = true
                } label: {
                    Text("Delete my data")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Delete my data")
                .accessibilityHint("Removes all CarbFlow data from this device after confirmation.")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
        )
    }

    private func bullet(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private func handleExport() {
        guard !isExporting else { return }
        cf_logEvent("privacy-export-start", ["ts": Date().timeIntervalSince1970])
        isExporting = true
        Task { @MainActor in
            do {
                let url = try exportService.exportData()
                exportURL = url
                showShareSheet = true
                cf_logEvent("privacy-export-complete", ["ts": Date().timeIntervalSince1970])
            } catch {
                exportErrorMessage = error.localizedDescription
                showExportError = true
                NonFatalReporter.report(error, context: ["flow": "privacy-export"])
                cf_logEvent("privacy-export-error", ["ts": Date().timeIntervalSince1970])
            }
            isExporting = false
        }
    }

    private func confirmDeletion() {
        guard !isDeleting else { return }
        cf_logEvent("privacy-delete-start", ["ts": Date().timeIntervalSince1970])
        isDeleting = true
        Task { @MainActor in
            do {
                try purgeService.purgeAll()
                cf_logEvent("privacy-delete-complete", ["ts": Date().timeIntervalSince1970])
                showDeletionComplete = true
            } catch {
                deletionErrorMessage = error.localizedDescription
                showDeletionError = true
                NonFatalReporter.report(error, context: ["flow": "privacy-delete"])
                cf_logEvent("privacy-delete-error", ["ts": Date().timeIntervalSince1970])
            }
            isDeleting = false
            showDeleteSheet = false
        }
    }

    private var deleteConfirmationSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Type DELETE to confirm")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("This removes all foods, logs, and settings from this device. It cannot be undone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("DELETE", text: $deleteConfirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                Button(role: .destructive) {
                    confirmDeletion()
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(isDeleting ? "Deleting..." : "Delete everything")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(deleteConfirmationText != "DELETE" || isDeleting)
                .accessibilityHint("Deletes all CarbFlow data when confirmed.")
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        deleteConfirmationText = ""
                        showDeleteSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}
