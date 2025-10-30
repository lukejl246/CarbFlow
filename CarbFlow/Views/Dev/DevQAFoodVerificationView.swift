#if DEBUG
import SwiftUI
import CoreData

@MainActor
struct DevQAFoodVerificationView: View {
    @State private var query: String = ""
    @State private var foods: [Food] = []
    @State private var searchTask: Task<Void, Never>?

    private let persistence = PersistenceController.shared
    private let debounceDuration: Duration = .milliseconds(300)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                searchBar

                if foods.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(foods, id: \.objectID) { food in
                            FoodVerificationRow(food: food, onToggle: { newValue in
                                updateVerificationStatus(for: food, isVerified: newValue)
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("QA: Food Verification")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadAllFoods)
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search foods", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No foods found")
                .font(.headline)
                .foregroundStyle(.secondary)

            if !query.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func loadAllFoods() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.fetchLimit = 500
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        request.predicate = NSPredicate(format: "isSoftDeleted == NO")
        foods = (try? context.fetch(request)) ?? []
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

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            loadAllFoods()
            return
        }

        let context = persistence.container.viewContext
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.fetchLimit = 500
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isSoftDeleted == NO"),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "name CONTAINS[cd] %@", trimmed),
                NSPredicate(format: "brand CONTAINS[cd] %@", trimmed)
            ])
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        foods = (try? context.fetch(request)) ?? []
    }

    private func updateVerificationStatus(for food: Food, isVerified: Bool) {
        let context = persistence.container.viewContext

        // Get the food in the view context if needed
        let foodInContext: Food
        if food.managedObjectContext == context {
            foodInContext = food
        } else {
            guard let fetchedFood = try? context.existingObject(with: food.objectID) as? Food else {
                print("[DevQA] Failed to fetch food in view context")
                return
            }
            foodInContext = fetchedFood
        }

        foodInContext.isVerified = isVerified

        do {
            if context.hasChanges {
                try context.save()
                print("[DevQA] Updated verification status for '\(foodInContext.name ?? "unknown")': \(isVerified)")

                // Also update any existing FoodItem that was created from this Food
                updateRelatedFoodItem(for: foodInContext, isVerified: isVerified)
            }
        } catch {
            print("[DevQA] Failed to save verification status: \(error)")
        }
    }

    private func updateRelatedFoodItem(for food: Food, isVerified: Bool) {
        let context = persistence.container.viewContext
        guard let foodID = food.id else { return }

        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", foodID as CVarArg)

        if let foodItem = try? context.fetch(request).first {
            foodItem.isVerified = isVerified
            try? context.save()
            print("[DevQA] Also updated related FoodItem")
        }
    }
}

private struct FoodVerificationRow: View {
    let food: Food
    let onToggle: (Bool) -> Void

    @State private var isVerified: Bool

    init(food: Food, onToggle: @escaping (Bool) -> Void) {
        self.food = food
        self.onToggle = onToggle
        _isVerified = State(initialValue: food.isVerified)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    statusLabel
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isVerified)
                .labelsHidden()
                .tint(.accentColor)
                .onChange(of: isVerified) { _, newValue in
                    onToggle(newValue)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var backgroundColor: Color {
        if isVerified {
            return Color.green.opacity(0.08)
        }
        return Color(.systemBackground)
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
            Text(isVerified ? "Verified" : "Not Verified")
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(isVerified ? .green : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#endif
