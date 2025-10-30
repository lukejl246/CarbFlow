import SwiftUI
import CoreData

/// Modal result view for barcode scan feedback with product preview
struct ScannerResultView: View {
    let barcode: String
    let onAddToLog: (CachedUPCItem) -> Void
    let onSearchManually: () -> Void
    let onTryAgain: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loadingState: LoadingState = .loading
    @State private var foundProduct: CachedUPCItem?

    enum LoadingState {
        case loading
        case found
        case notFound
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Spacer()
                Button {
                    dismiss()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityHint("Dismiss barcode result")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Content
            VStack(spacing: 20) {
                switch loadingState {
                case .loading:
                    loadingView
                case .found:
                    if let product = foundProduct {
                        foundView(product: product)
                    }
                case .notFound:
                    notFoundView
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(16)
        .task {
            await checkCache()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.accentColor)

            Text("Checking barcode...")
                .font(.body)
                .foregroundColor(.secondary)

            Text(barcode)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Found View

    private func foundView(product: CachedUPCItem) -> some View {
        VStack(spacing: 16) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.green)

            // Product info
            VStack(spacing: 8) {
                Text("Product Found")
                    .font(.headline)

                Text(product.name)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Net carbs chip
                HStack(spacing: 6) {
                    Text("\(product.netCarbs, specifier: "%.1f")g")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("net carbs")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(12)
            }

            // Barcode number
            Text(barcode)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            // Add to log button
            Button {
                dismiss()
                onAddToLog(product)
            } label: {
                Text("Add to Log")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(14)
            }
            .accessibilityHint("Add this product to your food log")
        }
    }

    // MARK: - Not Found View

    private var notFoundView: some View {
        VStack(spacing: 16) {
            // Not found icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.secondary)

            // Status text
            VStack(spacing: 8) {
                Text("Product Not Found")
                    .font(.headline)

                Text("We couldn't find this barcode in our database")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Barcode number
            Text(barcode)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.secondary)

            // Action buttons
            VStack(spacing: 12) {
                // Primary button - Search Manually
                Button {
                    dismiss()
                    onSearchManually()
                } label: {
                    Text("Search Manually")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(14)
                }
                .accessibilityHint("Search for this product manually")

                // Secondary button - Try Again
                Button {
                    dismiss()
                    onTryAgain()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Scan another barcode")
            }
        }
    }

    // MARK: - Cache Check

    private func checkCache() async {
        // Add brief delay to show loading state
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        guard FeatureFlags.cf_scancache else {
            // Flag disabled, always return not found
            await MainActor.run {
                loadingState = .notFound
            }
            return
        }

        // Lookup product in UPC cache
        if let cachedItem = await UPCCacheStore.shared.lookup(barcode) {
            await MainActor.run {
                foundProduct = cachedItem
                withAnimation(.easeInOut(duration: 0.25)) {
                    loadingState = .found
                }
            }
        } else {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    loadingState = .notFound
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Loading") {
    ScannerResultView(
        barcode: "012345678905",
        onAddToLog: { _ in },
        onSearchManually: {},
        onTryAgain: {},
        onDismiss: {}
    )
}

#Preview("Not Found") {
    struct PreviewWrapper: View {
        @State private var showSheet = true

        var body: some View {
            Color.clear
                .sheet(isPresented: $showSheet) {
                    ScannerResultView(
                        barcode: "012345678905",
                        onAddToLog: { _ in },
                        onSearchManually: {},
                        onTryAgain: {},
                        onDismiss: {}
                    )
                }
        }
    }

    return PreviewWrapper()
}
