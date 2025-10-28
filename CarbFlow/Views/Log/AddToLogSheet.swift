import SwiftUI
import CoreData

struct AddToLogSheet: View {
    let food: FoodItem
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1.0

    private var scaledNetCarbs: Double { food.netCarbs * servings }
    private var scaledCarbs: Double { food.carbs * servings }
    private var scaledFat: Double { food.fat * servings }
    private var scaledProtein: Double { food.protein * servings }
    private var scaledKcal: Double { food.kcal * servings }
    private var servingLabel: String {
        if let grams = food.servingSize {
            return "\(grams.roundedString()) g"
        }
        return "Per serving"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(food.name)
                            .font(.title3.weight(.semibold))
                        if let brand = food.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Serving: \(servingLabel)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                    VStack(spacing: 16) {
                        HStack {
                            Text("Servings")
                                .font(.headline)
                            Spacer()
                            Text(servings.roundedString())
                                .font(.headline)
                                .accessibilityLabel("\(servings.roundedString()) servings")
                        }

                        Slider(value: $servings, in: 0.5...3.0, step: 0.1)
                            .tint(.accentColor)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
                    )

                    VStack(spacing: 12) {
                        macroRow(title: "Net carbs", value: scaledNetCarbs, accent: true)
                        macroRow(title: "Total carbs", value: scaledCarbs)
                        macroRow(title: "Protein", value: scaledProtein)
                        macroRow(title: "Fat", value: scaledFat)
                        macroRow(title: "Calories", value: scaledKcal, suffix: " kcal")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
                    )
                }
                .padding(24)
            }
            .navigationTitle("Add to log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(servings)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Save to log")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.25), value: servings)
    }

    private func macroRow(title: String, value: Double, accent: Bool = false, suffix: String = " g") -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(value.roundedString())\(suffix)")
                .font(.headline)
                .foregroundStyle(accent ? Color.accentColor : .primary)
        }
    }
}

private extension Double {
    func roundedString() -> String {
        if truncatingRemainder(dividingBy: 1).isZero {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.1f", self)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let food = FoodItem(
        context: context,
        name: "Sample Food",
        brand: "Brand",
        servingSize: 100,
        carbs: 5,
        netCarbs: 3,
        fat: 2,
        protein: 20,
        kcal: 150,
        upc: "012345678901"
    )
    return AddToLogSheet(food: food, onSave: { _ in }, onCancel: { })
}
