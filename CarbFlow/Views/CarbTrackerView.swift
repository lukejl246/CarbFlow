import SwiftUI

struct CarbTrackerView: View {
    @EnvironmentObject private var carbStore: CarbIntakeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.carbTarget) private var carbTarget = 0

    @State private var customGrams: String = ""
    @State private var showClearConfirmation = false
    @State private var showLearnInfo = false

    private let quickAddOptions = [5, 10, 20, 50]

    private var isUnlocked: Bool {
        currentDay >= 3
    }

    private var gramsLeft: Int {
        guard carbTarget > 0 else { return 0 }
        return carbStore.gramsLeft(target: carbTarget)
    }

    private var headerSubtitle: String {
        if carbTarget > 0 {
            return "Target \(carbTarget) g • resets at midnight"
        }
        return "Set in Day 2"
    }

    private func addEntry(grams: Int) {
        let clamped = min(max(grams, 1), 500)
        carbStore.add(grams: clamped)
        customGrams = ""
    }

    private func undoLast() {
        guard let id = carbStore.entries.first?.id else { return }
        carbStore.remove(id)
    }

    var body: some View {
        Group {
            if isUnlocked {
                trackerContent
            } else {
                lockedContent
            }
        }
        .navigationTitle("Carbs today")
        .toolbar {
            if isUnlocked {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Undo") {
                        undoLast()
                    }
                    .disabled(carbStore.entries.isEmpty)

                    Button("Clear") {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear today’s entries?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear entries", role: .destructive) {
                carbStore.clearToday()
            }
        }
        .onAppear {
            if isUnlocked {
                carbStore.refreshIfNeeded()
            }
        }
        .alert("Learn Carb Targets", isPresented: $showLearnInfo, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text("Switch to the Learn tab and complete Day 2 to unlock carb tracking.")
        })
    }

    private var trackerContent: some View {
        List {
            headerSection

            quickAddSection

            customAddSection

            entriesSection

            totalSection
        }
        .listStyle(.insetGrouped)
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Carbs locked")
                .font(.title3.weight(.semibold))
            Text("Complete Day 2 – Carb Targets to enable carb tracking.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button("Go to Today") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Learn") {
                    showLearnInfo = true
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(carbTarget > 0 ? "\(gramsLeft) g left" : "— g")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var quickAddSection: some View {
        Section("Quick add") {
            let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(quickAddOptions, id: \.self) { value in
                    Button {
                        addEntry(grams: value)
                    } label: {
                        Text("+\(value)")
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var customAddSection: some View {
        Section("Custom") {
            HStack(spacing: 12) {
                TextField("Grams", text: $customGrams)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 80)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()

                Button("Add") {
                    guard let value = parsedCustomValue else { return }
                    addEntry(grams: value)
                }
                .disabled(parsedCustomValue == nil)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var entriesSection: some View {
        Section("Entries") {
            if carbStore.entries.isEmpty {
                Text("No entries yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(carbStore.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.grams) g")
                                .font(.headline)
                                .monospacedDigit()
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
        }
    }

    private var totalSection: some View {
        Section {
            HStack {
                Text("Total")
                Spacer()
                Text("\(carbStore.total) g")
                    .monospacedDigit()
                    .font(.headline)
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        offsets
            .map { carbStore.entries[$0] }
            .forEach { carbStore.remove($0.id) }
    }

    private var parsedCustomValue: Int? {
        let trimmed = customGrams.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else { return nil }
        return (1...500).contains(value) ? value : nil
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let carbStore = CarbIntakeStore()
    return NavigationStack {
        CarbTrackerView()
            .environmentObject(carbStore)
    }
}
