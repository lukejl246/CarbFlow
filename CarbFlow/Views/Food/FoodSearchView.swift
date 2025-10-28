import SwiftUI
import CoreData

struct FoodSearchView: View {
    @State private var query: String = ""
    @State private var predictions: [FoodPrediction] = []
    @State private var infoMessage: String? = "Start typing to search foods."
    @State private var isLoading: Bool = false
    @State private var seedVersion: Int64 = 0
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private let searcher: CFPredictiveSearch
    private let cache = FoodSearchCache.shared
    private let repository: FoodRepository

    @MainActor
    init(
        searcher: CFPredictiveSearch,
        repository: FoodRepository
    ) {
        self.searcher = searcher
        self.repository = repository
    }

    var body: some View {
        VStack(spacing: 20) {
            searchField
                .padding(.top, 24)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .transition(.opacity)
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(predictions, id: \.id) { prediction in
                        FoodPredictionRow(prediction: prediction)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: predictions)
        .animation(.easeInOut(duration: 0.25), value: infoMessage)
        .task {
            seedVersion = await fetchSeedVersion()
        }
        .onChange(of: query) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search foods…", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isSearchFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                    predictions = []
                    infoMessage = "Start typing to search foods."
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
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

    private func scheduleSearch(for text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            predictions = []
            infoMessage = "Start typing to search foods."
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        let predictiveEnabled = CFFlags.isEnabled(.cf_foodsearch)

        if predictiveEnabled && seedVersion == 0 {
            seedVersion = await fetchSeedVersion()
        }

        if predictiveEnabled,
           let cachedIDs = cache.get(query: query, seedVersion: seedVersion),
           let cachedPredictions = await loadPredictions(for: cachedIDs),
           !cachedPredictions.isEmpty {
            withAnimation(.easeInOut(duration: 0.25)) {
                predictions = cachedPredictions
                infoMessage = nil
                isLoading = false
            }
            return
        }

        if predictiveEnabled {
            do {
                let results = try await searcher.predict(query: query)
                withAnimation(.easeInOut(duration: 0.25)) {
                    predictions = results
                    infoMessage = results.isEmpty ? "No foods matched “\(query)”." : nil
                    isLoading = false
                }
                cache.save(query: query, ids: results.map(\.id), seedVersion: seedVersion)
            } catch {
                withAnimation(.easeInOut(duration: 0.25)) {
                    predictions = []
                    infoMessage = "Search failed. Please try again."
                    isLoading = false
                }
                #if DEBUG
                print("[FoodSearchView] Predictive search failed: \(error)")
                #endif
            }
        } else {
            do {
                let foods = try await repository.searchFoods(prefix: query, limit: 30)
                let mapped = foods.compactMap { food -> FoodPrediction? in
                    guard let id = food.id else { return nil }
                    guard let name = food.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
                    let brand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return FoodPrediction(
                        id: id,
                        name: name,
                        brand: brand?.isEmpty == false ? brand : nil,
                        netCarbsPer100g: food.netCarbsPer100g,
                        isVerified: food.isVerified,
                        score: 0
                    )
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    predictions = mapped
                    infoMessage = mapped.isEmpty ? "No foods matched “\(query)”." : nil
                    isLoading = false
                }
            } catch {
                withAnimation(.easeInOut(duration: 0.25)) {
                    predictions = []
                    infoMessage = "Search failed. Please try again."
                    isLoading = false
                }
                #if DEBUG
                print("[FoodSearchView] Basic search failed: \(error)")
                #endif
            }
        }
    }

    private func fetchSeedVersion() async -> Int64 {
        await MainActor.run {
            let context = CFPersistence.shared.viewContext
            let request: NSFetchRequest<MetaSeed> = MetaSeed.fetchRequest()
            request.fetchLimit = 1
            do {
                return try context.fetch(request).first?.version ?? 0
            } catch {
                return 0
            }
        }
    }

    private func loadPredictions(for ids: [UUID]) async -> [FoodPrediction]? {
        guard !ids.isEmpty else { return nil }
        let context = await MainActor.run { CFPersistence.shared.newBackgroundContext() }
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<Food> = Food.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@", ids)
                request.returnsObjectsAsFaults = false
                do {
                    let foods = try context.fetch(request)
                    let lookup = Dictionary(uniqueKeysWithValues: foods.compactMap { food -> (UUID, Food)? in
                        guard let uuid = food.id else { return nil }
                        return (uuid, food)
                    })
                    let ordered = ids.compactMap { id -> FoodPrediction? in
                        guard let food = lookup[id] else { return nil }
                        guard let name = food.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
                        let brand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
                        return FoodPrediction(
                            id: id,
                            name: name,
                            brand: brand?.isEmpty == false ? brand : nil,
                            netCarbsPer100g: food.netCarbsPer100g,
                            isVerified: food.isVerified,
                            score: 0
                        )
                    }
                    continuation.resume(returning: ordered)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private struct FoodPredictionRow: View {
    let prediction: FoodPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prediction.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if prediction.isVerified {
                    Text("Verified")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                if let brand = prediction.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(netCarbsText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var netCarbsText: String {
        "\(prediction.netCarbsPer100g.formatted(.number.precision(.fractionLength(1)))) g net carbs"
    }
}

#Preview {
    NavigationStack {
        FoodSearchViewPreview.view
            .navigationTitle("Search Foods")
    }
}

@MainActor
private enum FoodSearchViewPreview {
    static let view = FoodSearchView.makeDefault()
}

extension FoodSearchView {
    @MainActor
    static func makeDefault() -> FoodSearchView {
        FoodSearchView(
            searcher: CFPredictiveSearch(persistence: CFPersistence.shared),
            repository: FoodRepository(persistence: CFPersistence.shared)
        )
    }
}
