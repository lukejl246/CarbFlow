import SwiftUI

struct FoodLibraryHelpCard: View {
    var onDismiss: () -> Void
    var learnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text("Local starter foods are stored on your device. You can add more later via scan or manual entry. Data stays private.")
                .font(.body)
                .foregroundStyle(.primary)
            Button(action: learnMoreTapped) {
                Text("Learn more")
                    .font(.footnote.weight(.semibold))
                    .underline()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Not medical advice")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.medium)
            }
            .padding(12)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            analyticsEvent("food_library_help_open")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("About the food library")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private func learnMoreTapped() {
        analyticsEvent("food_library_help_link_tap")
        learnMore()
    }

    private func analyticsEvent(_ name: String) {
        #if DEBUG
        print("[Analytics] \(name)")
        #endif
    }
}
