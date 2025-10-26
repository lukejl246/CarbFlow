import SwiftUI

struct HomeView: View {
    @EnvironmentObject var contentStore: ContentStore

    @State private var showOverviewInfo = false

    private var totalDays: Int {
        max(contentStore.totalDays, 1)
    }

    private var day: Int {
        1
    }

    private var formattedDate: String {
        HomeView.dateFormatter.string(from: Date())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                    .padding(.horizontal, 20)

                overviewPlaceholder
                    .padding(.horizontal, 20)
            }
            .padding(.top, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                }
                .accessibilityLabel("Open Settings")
            }
        }
        .alert("Start a check-in", isPresented: $showOverviewInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Use the Today view however you like—capture a note, review habits, or simply reflect.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CarbFlow")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            HStack(alignment: .center, spacing: 12) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Day \(day) of \(totalDays)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }

            ProgressView(value: Double(day), total: Double(totalDays))
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
    }

    private var overviewPlaceholder: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Today")
                .font(.title3.weight(.semibold))

            Text("No preset plan. Tap below to jot a note, track habits, or plan a gentle focus.")
                .font(.body)
                .foregroundColor(.secondary)

            Button {
                showOverviewInfo = true
            } label: {
                Text("Start a check-in")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
}

#Preview {
    let store = ContentStore()
    return NavigationStack {
        HomeView()
            .environmentObject(store)
    }
}
