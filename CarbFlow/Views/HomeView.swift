import SwiftUI

struct HomeView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.streakCount) private var streakCount = 0
    @AppStorage(Keys.lastCompletionISO) private var lastCompletionISO = ""
    @AppStorage(Keys.username) private var username = ""
    @AppStorage(Keys.carbTarget) private var carbTarget = 30
    @State private var isSettingsPresented = false
    
    private var streakWeeks: Int {
        max(streakCount, 0) / 7
    }

    private var completedDays: Int {
        max(currentDay - 1, 0)
    }

    private var todayModule: DayModule {
        let modules = ProgramModel.modules
        guard !modules.isEmpty else {
            return DayModule(day: 1, title: "Getting Started", summary: "Stay tuned for your first lesson.")
        }
        let index = min(max(currentDay - 1, 0), modules.count - 1)
        return modules[index]
    }

    private var buttonTitle: String {
        currentDay <= 1 ? "Open Day 1" : "Open Day \(currentDay)"
    }

    private var greetingLine: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Welcome" : "Welcome, \(trimmed)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    headerPills
                    subtitle
                    moduleCard
                }
                .padding()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsSheet(resetAction: resetProgress)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .overlay(
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                Text("CarbFlow")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        )
    }

    private var headerPills: some View {
        HStack(spacing: 12) {
            headerPill(icon: "flame.fill", title: "\(streakWeeks) weeks", foreground: .orange)
            headerPill(icon: "paperplane.fill", title: "\(completedDays) days", foreground: .blue)
            headerPill(icon: "lock.fill", title: "Tracking", foreground: .secondary)
        }
    }

    private var subtitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingLine)
                .font(.title3)
                .fontWeight(.semibold)
            Text("To unlock, complete Day 1.")
                .foregroundColor(.secondary)
        }
    }

    private var moduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(todayModule.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(todayModule.summary)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                Spacer()

                Label("1 min", systemImage: "clock")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How it works")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                bulletLine("Read summary")
                bulletLine("Optional fast")
                bulletLine("Tap to review")
            }

            Text("Today's carb target: \(carbTarget) g")
                .font(.footnote)
                .foregroundColor(.secondary)

            NavigationLink(
                destination: DayDetailView(day: currentDay)
            ) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 6)
        )
    }

    private func headerPill(icon: String, title: String, foreground: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(foreground)
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.subheadline)
    }

    private func resetProgress() {
        currentDay = 1
        streakCount = 0
        lastCompletionISO = ""
    }
}

private struct SettingsSheet: View {
    let resetAction: () -> Void
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Button("Show Onboarding") {
                    hasOnboarded = false
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: {
                    resetAction()
                    dismiss()
                }) {
                    Text("Reset Progress")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
