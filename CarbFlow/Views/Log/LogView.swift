import SwiftUI
import Foundation
import CoreData

/// Offline behaviour: scanning, verification badges, and logging use only on-device Core Data and camera access with no network dependency.

struct LogView: View {
    @StateObject private var viewModel: LogViewModel
    @State private var showScanner = false
    @State private var showScannerPolicy = false
    @State private var showSearchSheet = false
    @State private var searchInitialQuery = ""
    @State private var showCustomEditor = false
    @State private var customInitialName = ""
    @State private var customFoodFeatureEnabled = CFFlags.isEnabled(.cf_foodcustom)
    @State private var hasLoggedAppear = false

    private let persistence: CFPersistence
    private let userRepository: UserFoodRepository
    private let foodRepository: FoodRepository
    private let predictiveSearch: CFPredictiveSearch

    init() {
        let persistence = CFPersistence.shared
        _viewModel = StateObject(wrappedValue: LogViewModel())
        self.persistence = persistence
        self.userRepository = UserFoodRepository(persistence: persistence)
        self.foodRepository = FoodRepository(persistence: persistence)
        self.predictiveSearch = CFPredictiveSearch(persistence: persistence)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scanCard
                searchCard
                if let code = viewModel.lastScannedCode {
                    lastScanSummary(code: code)
                } else {
                    placeholderCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            ScanSheet(
                onScanned: { code in
                    showScanner = false
                    viewModel.handleScanned(code: code)
                },
                onClose: {
                    showScanner = false
                }
            )
        }
        .sheet(isPresented: $showScannerPolicy) {
            ScannerPolicyCard {
                showScannerPolicy = false
            }
        }
        .sheet(isPresented: $showSearchSheet, onDismiss: {
            searchInitialQuery = ""
        }) {
            NavigationStack {
                FoodSearchView(
                    searcher: predictiveSearch,
                    repository: foodRepository,
                    userRepository: userRepository,
                    initialQuery: searchInitialQuery,
                    onFoodChosen: { food in
                        handleFoodSelection(food)
                    }
                )
                .navigationTitle("Search Foods")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showCustomEditor, onDismiss: {
            customInitialName = ""
        }) {
            NavigationStack {
                CustomFoodEditorView(
                    mode: .create,
                    repository: userRepository,
                    initialName: customInitialName,
                    onSaved: { food in
                        handleFoodSelection(food)
                    }
                )
            }
        }
        .sheet(item: $viewModel.activePresentation) { presentation in
            switch presentation {
            case .add(let food):
                AddToLogSheet(
                    food: food,
                    onSave: { servings in
                        viewModel.addToLog(food: food, servings: servings)
                    },
                    onCancel: {
                        viewModel.dismissPresentation()
                    }
                )
            case .notFound(let code, let message):
                NotFoundSheet(
                    code: code,
                    message: message,
                    customEnabled: customFoodFeatureEnabled,
                    onSearch: {
                        viewModel.trackSearchLibrary(for: code)
                        searchInitialQuery = ""
                        showSearchSheet = true
                    },
                    onCreate: {
                        viewModel.trackCreateCustom(for: code)
                        guard customFoodFeatureEnabled else { return }
                        customInitialName = ""
                        showCustomEditor = true
                    },
                    onDismiss: {
                        viewModel.dismissPresentation()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showScanner)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScannerPolicy = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.medium)
                }
                .accessibilityLabel("Scanner policy")
                .accessibilityHint("Learn how CarbFlow handles scanning.")
            }
        }
        .onAppear {
            customFoodFeatureEnabled = CFFlags.isEnabled(.cf_foodcustom)
            if !hasLoggedAppear {
                cf_logEvent("log-open", ["ts": Date().timeIntervalSince1970])
                hasLoggedAppear = true
            }
        }
        .onDisappear {
            cf_logEvent("log-close", ["ts": Date().timeIntervalSince1970])
        }
        .onReceive(NotificationCenter.default.publisher(for: .cfFoodCustomFlagDidChange)) { _ in
            let enabled = CFFlags.isEnabled(.cf_foodcustom)
            customFoodFeatureEnabled = enabled
            if !enabled {
                showCustomEditor = false
            }
        }
    }

    private var scanCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showScanner = true
            }
            cf_logEvent("log-scan-open", ["ts": Date().timeIntervalSince1970])
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan to log quickly")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Point the camera at a barcode to start adding food.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Uses your camera to capture UPCs. Minimum lighting recommended.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan to log quickly")
        .accessibilityHint("Opens the camera to scan a food barcode.")
    }

    private var searchCard: some View {
        Button {
            searchInitialQuery = ""
            withAnimation(.easeInOut(duration: 0.25)) {
                showSearchSheet = true
            }
            cf_logEvent("log-search-open", ["ts": Date().timeIntervalSince1970])
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse foods manually")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Search the library or add your own custom food.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(customFoodFeatureEnabled ? "Includes your custom foods alongside the CarbFlow database." : "Search the CarbFlow food library without using the scanner.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse foods manually")
        .accessibilityHint("Opens search to find foods or add a custom entry.")
    }

    private func lastScanSummary(code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last scan")
                .font(.headline)
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("We saved this barcode for the next step in the logging flow.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing scanned yet")
                .font(.headline)
            Text("When you scan a barcode, it will appear here so you can confirm before logging.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @MainActor
    private func handleFoodSelection(_ food: Food) {
        do {
            let context = persistence.viewContext
            let item = try food.ensureFoodItem(in: context)
            if context.hasChanges {
                try context.save()
            }
            viewModel.activePresentation = .add(food: item)
            showSearchSheet = false
            showCustomEditor = false
        } catch {
            #if DEBUG
            print("[LogView] Failed to prepare food item for logging: \(error)")
            #endif
        }
    }
}

private struct NotFoundSheet: View {
    let code: String
    let message: String
    let customEnabled: Bool
    let onSearch: () -> Void
    let onCreate: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("We couldn't find that barcode")
                        .font(.title3.weight(.semibold))
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("UPC: \(code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                VStack(spacing: 12) {
                    Button {
                        onSearch()
                        close()
                    } label: {
                        Text("Search the food library")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    if customEnabled {
                        Button {
                            onCreate()
                            close()
                        } label: {
                            Text("Create a custom food")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        close()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func close() {
        onDismiss()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LogView()
    }
}
