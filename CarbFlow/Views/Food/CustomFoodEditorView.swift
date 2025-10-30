import SwiftUI
import CoreData

struct CustomFoodEditorView: View {
    enum Mode: Equatable {
        case create
        case edit(Food)

        var title: String {
            switch self {
            case .create:
                return NSLocalizedString("food_custom_add_title", comment: "")
            case .edit:
                return "Edit Custom Food"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private let mode: Mode
    private let repository: UserFoodRepository
    private let onSaved: (Food) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var servingValue: String
    @State private var servingUnit: String
    @State private var netCarbs: String
    @State private var protein: String
    @State private var fat: String
    @State private var notes: String
    @State private var barcode: String

    @State private var showValidationMessages: Bool = false
    @State private var touchedFields: Set<Field> = []
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    init(
        mode: Mode,
        repository: UserFoodRepository,
        initialName: String? = nil,
        initialBarcode: String? = nil,
        onSaved: @escaping (Food) -> Void
    ) {
        self.mode = mode
        self.repository = repository
        self.onSaved = onSaved

        switch mode {
        case .create:
            _name = State(initialValue: initialName ?? "")
            _brand = State(initialValue: "")
            _servingValue = State(initialValue: "")
            _servingUnit = State(initialValue: "")
            _netCarbs = State(initialValue: "")
            _protein = State(initialValue: "")
            _fat = State(initialValue: "")
            _notes = State(initialValue: "")
            _barcode = State(initialValue: initialBarcode ?? "")
        case .edit(let food):
            _name = State(initialValue: food.name ?? "")
            _brand = State(initialValue: food.brand ?? "")
            if let value = food.value(forKey: "servingSizeValue") as? Double {
                _servingValue = State(initialValue: Self.formatter.string(from: NSNumber(value: value)) ?? "")
            } else {
                _servingValue = State(initialValue: "")
            }
            _servingUnit = State(initialValue: food.servingSizeUnit ?? "")
            _netCarbs = State(initialValue: Self.formatter.string(from: NSNumber(value: food.netCarbsPer100g)) ?? "")
            _protein = State(initialValue: Self.formatter.string(from: NSNumber(value: food.proteinPer100g)) ?? "")
            _fat = State(initialValue: Self.formatter.string(from: NSNumber(value: food.fatPer100g)) ?? "")
            _notes = State(initialValue: food.notes ?? "")
            _barcode = State(initialValue: food.upc ?? "")
        }
    }

    private enum Field: Hashable {
        case name, brand, servingValue, servingUnit, netCarbs, protein, fat, notes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                errorView

                VStack(spacing: 20) {
                    inputGroup(
                        title: "Name",
                        placeholder: "e.g. Greek yoghurt",
                        text: $name,
                        field: .name,
                        error: nameError
                    )

                    inputGroup(
                        title: "Brand",
                        placeholder: "Optional",
                        text: $brand,
                        field: .brand,
                        error: brandError
                    )

                    servingInputs

                    macroInputs

                    notesInput
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }

            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
        .animation(.easeInOut(duration: 0.25), value: saveError)
        .animation(.easeInOut(duration: 0.25), value: nameError)
        .animation(.easeInOut(duration: 0.25), value: brandError)
        .animation(.easeInOut(duration: 0.25), value: servingError)
        .animation(.easeInOut(duration: 0.25), value: netCarbsError)
        .animation(.easeInOut(duration: 0.25), value: proteinError)
        .animation(.easeInOut(duration: 0.25), value: fatError)
    }

    // MARK: - Toolbar buttons

    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Cancel")
        .accessibilityHint("Discard changes and close")
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            if isSaving {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Text("Save")
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .disabled(!formIsValid || isSaving)
        .accessibilityLabel(isSaving ? "Saving" : "Save")
        .accessibilityHint("Save custom food")
    }

    // MARK: - Input sections

    @ViewBuilder
    private var errorView: some View {
        if let saveError {
            Text(saveError)
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
                .transition(.opacity)
                .accessibilityLabel("Error")
                .accessibilityValue(saveError)
        }
    }

    @ViewBuilder
    private func inputGroup(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        error: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(error == nil ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit { focusNext(after: field) }
                .onChange(of: text.wrappedValue) { _, _ in
                    touchedFields.insert(field)
                }
                .accessibilityLabel(title)
                .accessibilityHint(placeholder)
                .accessibilityValue(text.wrappedValue.isEmpty ? "Empty" : text.wrappedValue)

            if let error, shouldShowError(for: field) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private var servingInputs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serving Size")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                TextField("Value", text: $servingValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(servingError == nil ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .servingValue)
                    .submitLabel(.next)
                    .onSubmit { focusNext(after: .servingValue) }
                    .onChange(of: servingValue) { _, _ in
                        touchedFields.insert(.servingValue)
                    }
                    .accessibilityLabel("Serving size value")
                    .accessibilityHint("Enter the numeric value for serving size")
                    .accessibilityValue(servingValue.isEmpty ? "Empty" : servingValue)

                TextField("Unit (g, ml…)", text: $servingUnit)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .focused($focusedField, equals: .servingUnit)
                    .submitLabel(.next)
                    .onSubmit { focusNext(after: .servingUnit) }
                    .accessibilityLabel("Serving size unit")
                    .accessibilityHint("Enter the unit like grams, milliliters, etc")
                    .accessibilityValue(servingUnit.isEmpty ? "Empty" : servingUnit)
            }

            if let servingError, shouldShowError(for: .servingValue) {
                Text(servingError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private var macroInputs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macros per 100g")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                macroField(
                    title: "Net Carbs",
                    text: $netCarbs,
                    field: .netCarbs,
                    error: netCarbsError
                )

                macroField(
                    title: "Protein",
                    text: $protein,
                    field: .protein,
                    error: proteinError
                )

                macroField(
                    title: "Fat",
                    text: $fat,
                    field: .fat,
                    error: fatError
                )
            }
        }
    }

    private func macroField(
        title: String,
        text: Binding<String>,
        field: Field,
        error: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(error == nil ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit { focusNext(after: field) }
                .onChange(of: text.wrappedValue) { _, _ in
                    touchedFields.insert(field)
                }
                .accessibilityLabel("\(title) per 100 grams")
                .accessibilityHint("Enter the amount in grams")
                .accessibilityValue(text.wrappedValue.isEmpty ? "Empty" : "\(text.wrappedValue) grams")

            if let error, shouldShowError(for: field) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.primary)

            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(notesError == nil ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                )
                .focused($focusedField, equals: .notes)
                .accessibilityLabel("Notes")
                .accessibilityHint("Optional notes about this food")
                .accessibilityValue(notes.isEmpty ? "Empty" : notes)

            if let notesError, showValidationMessages {
                Text(notesError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Validation

    private var nameError: String? {
        let normalized = normaliseName(name)
        if normalized.isEmpty {
            return NSLocalizedString("food_custom_validation_name", comment: "")
        }
        return nil
    }

    private var brandError: String? {
        if !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           normaliseName(brand).isEmpty {
            return "Brand looks empty."
        }
        return nil
    }

    private var servingError: String? {
        guard !servingValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let value = parseDouble(servingValue) else {
            return "Enter a number."
        }
        if value <= 0 {
            return "Must be above zero."
        }
        return nil
    }

    private var netCarbsError: String? {
        requiredMacroMessage(for: netCarbs)
    }

    private var proteinError: String? {
        requiredMacroMessage(for: protein)
    }

    private var fatError: String? {
        requiredMacroMessage(for: fat)
    }

    private var notesError: String? {
        nil // notes optional, reserved if future validation needed
    }

    private func requiredMacroMessage(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Required."
        }
        guard let parsed = parseDouble(trimmed) else {
            return "Enter a number."
        }
        if parsed < 0 {
            return "Must be 0 or more."
        }
        if parsed > 1_000 {
            return "Looks too high."
        }
        return nil
    }

    private var formIsValid: Bool {
        if nameError != nil || netCarbsError != nil || proteinError != nil || fatError != nil {
            return false
        }
        if servingError != nil {
            return false
        }

        guard let carbs = parseDouble(netCarbs),
              let prot = parseDouble(protein),
              let fats = parseDouble(fat),
              validateMacros(netCarbsPer100g: carbs, protein: prot, fat: fats) else {
            return false
        }

        return true
    }

    // MARK: - Actions

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        showValidationMessages = true
        saveError = nil

        guard formIsValid,
              let carbs = parseDouble(netCarbs),
              let prot = parseDouble(protein),
              let fats = parseDouble(fat) else {
            return
        }

        isSaving = true

        do {
            switch mode {
            case .create:
                let input = buildNewUserFoodInput(carbs: carbs, protein: prot, fat: fats)
                let saved = try await repository.create(input)
                onSaved(saved)
            case .edit(let existing):
                let objectID = existing.objectID
                let patch = buildPatch(for: existing, carbs: carbs, protein: prot, fat: fats)
                try await repository.update(id: objectID, with: patch)
                if let context = existing.managedObjectContext,
                   let updated = try? context.existingObject(with: objectID) as? Food {
                    onSaved(updated)
                }
            }

            dismiss()
        } catch let error as UserFoodRepositoryError {
            switch error {
            case .duplicate:
                saveError = NSLocalizedString("food_custom_duplicate", comment: "")
            case .notFound:
                saveError = "Could not save. Please try again."
            }
            #if DEBUG
            print("[CustomFoodEditorView] Save failed: \(error)")
            #endif
        } catch {
            saveError = "Could not save. Please try again."
            #if DEBUG
            print("[CustomFoodEditorView] Save failed: \(error)")
            #endif
        }

        isSaving = false
    }

    private func buildNewUserFoodInput(
        carbs: Double,
        protein: Double,
        fat: Double
    ) -> NewUserFoodInput {
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = servingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        return NewUserFoodInput(
            name: name,
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
            servingSizeValue: parseDouble(servingValue),
            servingSizeUnit: trimmedUnit.isEmpty ? nil : trimmedUnit,
            netCarbsPer100g: carbs,
            proteinPer100g: protein,
            fatPer100g: fat,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            upc: trimmedBarcode.isEmpty ? nil : trimmedBarcode
        )
    }

    private func buildPatch(
        for food: Food,
        carbs: Double,
        protein: Double,
        fat: Double
    ) -> FoodPatch {
        let normalizedName = name
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = servingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        let currentBrand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brandUpdate: Update<String>?
        if trimmedBrand.isEmpty {
            brandUpdate = currentBrand.isEmpty ? nil : .clear
        } else if trimmedBrand != currentBrand {
            brandUpdate = .set(trimmedBrand)
        } else {
            brandUpdate = nil
        }

        let currentUnit = food.servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let unitUpdate: Update<String>?
        if trimmedUnit.isEmpty {
            unitUpdate = currentUnit.isEmpty ? nil : .clear
        } else if trimmedUnit != currentUnit {
            unitUpdate = .set(trimmedUnit)
        } else {
            unitUpdate = nil
        }

        let currentServing = food.value(forKey: "servingSizeValue") as? Double
        let servingUpdate: Update<Double>?
        if let parsed = parseDouble(servingValue) {
            if currentServing != parsed {
                servingUpdate = .set(parsed)
            } else {
                servingUpdate = nil
            }
        } else {
            servingUpdate = currentServing == nil ? nil : .clear
        }

        let currentNotes = food.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notesUpdate: Update<String>?
        if trimmedNotes.isEmpty {
            notesUpdate = currentNotes.isEmpty ? nil : .clear
        } else if trimmedNotes != currentNotes {
            notesUpdate = .set(trimmedNotes)
        } else {
            notesUpdate = nil
        }

        let currentBarcode = food.upc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let barcodeUpdate: Update<String>?
        if trimmedBarcode.isEmpty {
            barcodeUpdate = currentBarcode.isEmpty ? nil : .clear
        } else if trimmedBarcode != currentBarcode {
            barcodeUpdate = .set(trimmedBarcode)
        } else {
            barcodeUpdate = nil
        }

        let updatedAt = Date()

        return FoodPatch(
            name: normalizedName != (food.name ?? "") ? normalizedName : nil,
            brand: brandUpdate,
            servingSizeValue: servingUpdate,
            servingSizeUnit: unitUpdate,
            netCarbsPer100g: carbs != food.netCarbsPer100g ? carbs : nil,
            proteinPer100g: protein != food.proteinPer100g ? protein : nil,
            fatPer100g: fat != food.fatPer100g ? fat : nil,
            notes: notesUpdate,
            upc: barcodeUpdate,
            updatedAt: updatedAt
        )
    }

    private func focusNext(after field: Field) {
        switch field {
        case .name: focusedField = .brand
        case .brand: focusedField = .servingValue
        case .servingValue: focusedField = .servingUnit
        case .servingUnit: focusedField = .netCarbs
        case .netCarbs: focusedField = .protein
        case .protein: focusedField = .fat
        case .fat: focusedField = .notes
        case .notes: focusedField = nil
        }
    }

    private func parseDouble(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func shouldShowError(for field: Field) -> Bool {
        showValidationMessages || touchedFields.contains(field)
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        return formatter
    }()
}
