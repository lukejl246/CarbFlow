import SwiftUI
import Foundation
import Combine
import UIKit
import CoreData

private enum CameraAlertType: Identifiable {
    case denied
    case restricted
    case unavailable(String)
    case generic(String)

    var id: String {
        switch self {
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .unavailable: return "unavailable"
        case .generic: return "generic"
        }
    }

    var title: String {
        switch self {
        case .denied: return "Camera Access Needed"
        case .restricted: return "Camera Restricted"
        case .unavailable: return "Camera Unavailable"
        case .generic: return "Camera Error"
        }
    }

    var message: String {
        switch self {
        case .denied:
            return "Camera access is turned off. You can enable it in Settings to scan barcodes."
        case .restricted:
            return "Camera access is restricted on this device."
        case .unavailable(let reason):
            return reason
        case .generic(let reason):
            return reason
        }
    }
}

struct FoodLibraryView: View {
    @State private var query: String = ""
    @State private var items: [FoodItem] = []
    @State private var showHelp = false
    @State private var showScanner = false
    @State private var cameraAlert: CameraAlertType?
    @State private var isRequestingCamera = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var queryFocused: Bool

    private let store = FoodStore()
    private let debounceDuration: Duration = .milliseconds(300)
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVStack(spacing: 16) {
                    ForEach(items, id: \.objectID) { item in
                        FoodRow(item: item)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            bottomControls
                .padding(.bottom, keyboardOffset)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Food Library")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelp) {
            FoodLibraryHelpCard(onDismiss: { showHelp = false }, learnMore: {})
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                ScannerCameraView(
                    onCodeDetected: handleScannerResult
                )
                .navigationTitle("Scan Barcode")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            showScanner = false
                        }
                        .accessibilityLabel("Close scanner")
                    }
                }
            }
        }
        .onAppear(perform: handleAppear)
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .alert(
            cameraAlert?.title ?? "",
            isPresented: Binding(
                get: { cameraAlert != nil },
                set: { if !$0 { cameraAlert = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    cameraAlert = nil
                }
            },
            message: {
                Text(cameraAlert?.message ?? "")
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }

    private var searchInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search foods", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($queryFocused)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .frame(maxWidth: .infinity)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                searchInput
                if FeatureFlags.scanEnabled {
                    Button {
                        queryFocused = false
                        handleScanButtonTap()
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scan barcode")
                    .disabled(isRequestingCamera)
                }
            }
            Button {
                showHelp = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.medium)
                    Text("About the food library")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open food library help")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, bottomPadding)
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        )
    }

    private func handleAppear() {
        analyticsEvent("food_library_open", ["timestamp": Date().timeIntervalSince1970])
        loadAll()
    }

    private func handleQueryChange(_ newValue: String) {
        searchTask?.cancel()
        searchTask = Task { [query] in
            try? await Task.sleep(for: debounceDuration)
            if Task.isCancelled { return }
            await MainActor.run {
                performSearch(query: query)
            }
        }
    }

    private var keyboardOffset: CGFloat {
        max(0, keyboardHeight - safeAreaBottomInset)
    }

    private var bottomPadding: CGFloat {
        let base: CGFloat = 16
        let inset = safeAreaBottomInset
        return (inset > 0 ? inset : base) + 8
    }

    private var safeAreaBottomInset: CGFloat {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }

    private func loadAll() {
        items = store.all(limit: 200)
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            loadAll()
            return
        }
        let results = store.search(trimmed, limit: 200)
        items = results
        analyticsEvent("food_library_search", [
            "query": trimmed,
            "result_count": results.count
        ])
    }

    private func handleScanButtonTap() {
        guard !isRequestingCamera else { return }
        Task {
            await requestCameraAccessAndPresent()
        }
    }

    private func requestCameraAccessAndPresent() async {
        await MainActor.run {
            isRequestingCamera = true
        }
        var status = await ScanPermissions.checkCameraAuthorization()
        if status == .notDetermined {
            status = await ScanPermissions.requestCameraAuthorization()
        }

        await MainActor.run {
            isRequestingCamera = false
            switch status {
            case .authorized:
                showScanner = true
            case .denied:
                cameraAlert = .denied
            case .restricted:
                cameraAlert = .restricted
            case .notDetermined:
                cameraAlert = .generic("Camera permission is still pending. Try again shortly.")
            }
        }
    }

    private func handleScannerResult(_ code: String) {
        showScanner = false
        searchTask?.cancel()
        query = code
        performSearch(query: code)
        analyticsEvent("food_library_scan_detected", ["code": code])
    }


    private func analyticsEvent(_ name: String, _ params: [String: Any]) {
        #if DEBUG
        print("[Analytics] \(name) \(params)")
        #endif
    }
}

private struct FoodRow: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
                #if DEBUG
                if item.isVerified {
                    VerifiedBadge()
                        .padding(.top, 2)
                        .onAppear {
                            VerifiedImpressionTracker.shared.track(item: item)
                        }
                }
                #endif
            }

            if let brand = item.brand, !brand.isEmpty {
                Text(brand)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            macroLine
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var macroLine: some View {
        HStack(spacing: 12) {
            macroChip(title: "Net Carbs", value: item.netCarbs, accent: true)
            macroChip(title: "Fat", value: item.fat)
            macroChip(title: "Protein", value: item.protein)
            macroChip(title: "kcal", value: item.kcal, suffix: "")
        }
        .font(.caption.weight(.semibold))
    }

    private func macroChip(title: String, value: Double, accent: Bool = false, suffix: String = "g") -> some View {
        let formatted: String
        if value.truncatingRemainder(dividingBy: 1).isZero {
            formatted = String(format: "%.0f", value)
        } else {
            formatted = String(format: "%.1f", value)
        }
        return Text("\(title): \(formatted)\(suffix)")
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .foregroundColor(accent ? .accentColor : .secondary)
    }

    private var accessibilitySummary: String {
        var pieces: [String] = [item.name]
        if let brand = item.brand, !brand.isEmpty {
            pieces.append("brand \(brand)")
        }
        #if DEBUG
        if item.isVerified {
            pieces.append("verified")
        }
        #endif
        pieces.append("net carbs \(Int(item.netCarbs)) grams")
        pieces.append("fat \(Int(item.fat)) grams")
        pieces.append("protein \(Int(item.protein)) grams")
        pieces.append("\(Int(item.kcal)) calories")
        return pieces.joined(separator: ", ")
    }
}

private final class VerifiedImpressionTracker {
    static let shared = VerifiedImpressionTracker()
    private var seen: Set<String> = []
    private let lock = NSLock()

    func track(item: FoodItem) {
        let key = item.objectID.uriRepresentation().absoluteString
        lock.lock()
        let shouldLog = seen.insert(key).inserted
        lock.unlock()
        guard shouldLog else { return }
        let params: [String: Any] = [
            "ts": Date().timeIntervalSince1970
        ]
        cf_logEvent("food-verified-impression", params)
    }
}
