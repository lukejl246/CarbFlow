import SwiftUI

/// Offline behaviour: displays static copy and links to Privacy view without any network lookups.

struct ScannerPolicyCard: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Scanner policy")
                            .font(.title3.weight(.semibold))
                        Text("Scanner stays free. No ads. No data selling.")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("CarbFlow only reads barcodes on your device so you can keep logging without sharing data.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            PrivacyView()
                                .onAppear {
                                    cf_logEvent("scanner-policy-link-tap", ["ts": Date().timeIntervalSince1970])
                                }
                        } label: {
                            Text("Learn more")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Learn more about privacy")
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
                    )
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Scanner policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
        .onAppear {
            cf_logEvent("scanner-policy-open", ["ts": Date().timeIntervalSince1970])
        }
        .onDisappear {
            cf_logEvent("scanner-policy-close", ["ts": Date().timeIntervalSince1970])
        }
    }
}

#Preview {
    ScannerPolicyCard(onClose: {})
}
