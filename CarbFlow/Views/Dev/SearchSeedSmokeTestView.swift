#if DEBUG

import SwiftUI
import CoreData
import UIKit

struct SearchSeedSmokeTestView: View {
    @State private var query: String = ""
    @State private var results: [FoodDisplayItem] = []
    @State private var selectedItem: FoodDisplayItem?
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var infoMessage: String?
    @State private var isSeeding: Bool = false

    private let repository: FoodRepository

    @MainActor
    init(repository: FoodRepository) {
        self.repository = repository
    }

    var body: some View {
        Group {
            if CFFlags.isEnabled(.cf_fooddb) {
                content
            } else {
                disabledState
            }
        }
        .navigationTitle("Seed Search (Debug)")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6).ignoresSafeArea())
        .onDisappear {
            searchTask?.cancel()
        }
        .sheet(item: $selectedItem) { item in
            FoodDetailSheet(item: item)
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            searchField
            
            if let infoMessage {
                HStack(spacing: 10) {
                    if isSeeding {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(results) { item in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedItem = item
                        } label: {
                            FoodResultRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 24)
        .animation(.easeInOut(duration: 0.25), value: results)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: infoMessage)
        .onChange(of: query) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .task {
            await ensureSeedsAvailable()
            scheduleSearch(for: query)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search seeded foods…", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
    }

    private var disabledState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Food database flag is off.")
                .font(.headline)

            Text("Enable cf_fooddb in Settings ▸ Developer Tools to exercise the seeded search smoke test.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleSearch(for text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))

            guard !Task.isCancelled else { return }
            await runSearch(text: text)
        }
    }

    @MainActor
    private func runSearch(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.25)) {
                results = []
                errorMessage = nil
                infoMessage = nil
            }
            return
        }

        do {
            let foods = try await repository.searchFoods(prefix: trimmed, limit: 30)
            let mapped = foods.map { FoodDisplayItem(food: $0) }
            withAnimation(.easeInOut(duration: 0.25)) {
                results = mapped
                errorMessage = nil
                infoMessage = mapped.isEmpty ? "No matches yet. If seeding just ran, try again in a moment." : nil
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.25)) {
                results = []
                errorMessage = "Search failed: \(error.localizedDescription)"
                infoMessage = nil
            }
        }
    }
}

private extension SearchSeedSmokeTestView {
    func ensureSeedsAvailable() async {
        guard CFFlags.isEnabled(.cf_fooddb) else { return }

        do {
            let count = try await repository.countAll()
            guard count == 0 else { return }

            await MainActor.run {
                isSeeding = true
                infoMessage = "Installing seed data…"
            }

            await installSeeds()

            await MainActor.run {
                isSeeding = false
                infoMessage = "Seed data ready. Try searching again."
            }
        } catch {
            await MainActor.run {
                infoMessage = "Unable to verify seeds: \(error.localizedDescription)"
                isSeeding = false
            }
        }
    }

    func installSeeds() async {
        let context = await MainActor.run { CFPersistence.shared.newBackgroundContext() }
        CFSeedInstaller.installIfNeeded(
            seedResourceName: "foods_seed_v1",
            seedVersion: 1,
            context: context
        )

        await withCheckedContinuation { continuation in
            context.perform {
                continuation.resume()
            }
        }
    }
}

// MARK: - Supporting Views

private struct FoodResultRow: View {
    let item: FoodDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if item.isVerified {
                    Text("Verified")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                        )
                }
            }

            if let brand = item.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct FoodDetailSheet: View {
    let item: FoodDisplayItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                macroGrid
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Food Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if let brand = item.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if item.isVerified {
                Text("Verified seed data")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        )
    }

    private var macroGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macros per 100g")
                .font(.headline)

            VStack(spacing: 12) {
                macroRow(label: "Net Carbs", value: item.netCarbsPer100g, suffix: "g")
                macroRow(label: "Protein", value: item.proteinPer100g, suffix: "g")
                macroRow(label: "Fat", value: item.fatPer100g, suffix: "g")
                macroRow(label: "Typical Portion", value: item.portionGram, suffix: "g")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
        }
    }

    private func macroRow(label: String, value: Double, suffix: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(" \(suffix)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Model

private struct FoodDisplayItem: Identifiable, Equatable {
    let id: NSManagedObjectID
    let name: String
    let brand: String?
    let isVerified: Bool
    let portionGram: Double
    let netCarbsPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double

    init(food: Food) {
        id = food.objectID
        name = food.name ?? "Unnamed"
        if let rawBrand = food.brand, !rawBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            brand = rawBrand
        } else {
            brand = nil
        }
        isVerified = food.isVerified
        portionGram = food.portionGram
        netCarbsPer100g = food.netCarbsPer100g
        proteinPer100g = food.proteinPer100g
        fatPer100g = food.fatPer100g
    }
}

extension SearchSeedSmokeTestView {
    @MainActor
    static func makeDefault() -> SearchSeedSmokeTestView {
        SearchSeedSmokeTestView(
            repository: FoodRepository(persistence: CFPersistence.shared)
        )
    }
}

#endif
