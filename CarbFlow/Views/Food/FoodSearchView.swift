import SwiftUI
import CoreData

struct FoodSearchView: View {
    @State private var query: String
    @State private var predictions: [FoodPrediction] = []
    @State private var infoMessage: String? = "Start typing to search foods."
    @State private var isLoading: Bool = false
    @State private var seedVersion: Int64 = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var isPresentingCustomEditor: Bool = false
    @State private var customDraftName: String = ""
    @State private var customFoodFeatureEnabled: Bool
    @FocusState private var isSearchFocused: Bool

    private let searcher: CFPredictiveSearch
    private let cache = FoodSearchCache.shared
    private let repository: FoodRepository
    private let userRepository: UserFoodRepository
    private let onFoodChosen: (Food) -> Void

    @MainActor
    init(
        searcher: CFPredictiveSearch,
        repository: FoodRepository,
        userRepository: UserFoodRepository,
        initialQuery: String = "",
        onFoodChosen: @escaping (Food) -> Void = { _ in }
    ) {
        self.searcher = searcher
        self.repository = repository
        self.userRepository = userRepository
        self.onFoodChosen = onFoodChosen
        self._query = State(initialValue: initialQuery)
        self._customFoodFeatureEnabled = State(initialValue: CFFlags.isEnabled(.cf_foodcustom))
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
                    if shouldShowCustomCTA {
                        addCustomFoodButton
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ForEach(predictions, id: \.id) { prediction in
                        Button {
                            Task { await selectPrediction(prediction) }
                        } label: {
                            FoodPredictionRow(prediction: prediction)
                        }
                        .buttonStyle(.plain)
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
            customFoodFeatureEnabled = CFFlags.isEnabled(.cf_foodcustom)
            seedVersion = await fetchSeedVersion()
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                scheduleSearch(for: trimmed)
            }
        }
        .onChange(of: query) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cfFoodCustomFlagDidChange)) { _ in
            let enabled = CFFlags.isEnabled(.cf_foodcustom)
            customFoodFeatureEnabled = enabled
            if !enabled {
                isPresentingCustomEditor = false
            }
        }
        .sheet(
            isPresented: Binding(
                get: { customFoodFeatureEnabled && isPresentingCustomEditor },
                set: { newValue in
                    isPresentingCustomEditor = newValue
                }
            ),
            onDismiss: {
            customDraftName = ""
        }) {
            NavigationStack {
                CustomFoodEditorView(
                    mode: .create,
                    repository: userRepository,
                    initialName: customDraftName,
                    onSaved: { food in
                        onFoodChosen(food)
                        isPresentingCustomEditor = false
                        searchTask?.cancel()
                        isLoading = false
                        isSearchFocused = false
                        query = ""
                        predictions = []
                        let displayName = (food.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let messageName = displayName.isEmpty ? "custom food" : displayName
                        infoMessage = "Added \(messageName)."
                    }
                )
            }
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
    }

    private var shouldShowCustomCTA: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return customFoodFeatureEnabled && !trimmed.isEmpty && !isLoading && predictions.isEmpty
    }

    private var addCustomFoodButton: some View {
        let suggestedName = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return Button {
            customDraftName = suggestedName
            isPresentingCustomEditor = true
            searchTask?.cancel()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add custom food")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(suggestedName.isEmpty ? "Use your own nutrition details" : "Create “\(suggestedName)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add custom food")
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
    private func selectPrediction(_ prediction: FoodPrediction) async {
        do {
            if let food = try await repository.food(by: prediction.id) {
                onFoodChosen(food)
            }
        } catch {
            #if DEBUG
            print("[FoodSearchView] Failed to load selected food: \(error)")
            #endif
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
                .fill(Color(.systemBackground))
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
            repository: FoodRepository(persistence: CFPersistence.shared),
            userRepository: UserFoodRepository(persistence: CFPersistence.shared)
        )
    }
}
