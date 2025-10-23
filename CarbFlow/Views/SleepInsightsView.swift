import SwiftUI

struct SleepInsightsView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @EnvironmentObject private var contentStore: ContentStore
    @Environment(\.dismiss) private var dismiss

    @State private var showLearnAlert = false

    private var sleepUnlockDay: Int {
        contentStore.days.first {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveContains("Sleep & Recovery")
        }?.day ?? 22
    }

    private var isUnlocked: Bool {
        currentDay > sleepUnlockDay
    }

    var body: some View {
        Group {
            if isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .navigationTitle("Sleep insights")
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Learn Sleep & Recovery", isPresented: $showLearnAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text("Switch to the Learn tab and finish Sleep & Recovery to unlock sleep insights.")
        })
    }

    private var unlockedContent: some View {
        List {
            Section("Overview") {
                Text("Sleep tracking and recovery insights are coming soon. For now, keep focusing on consistent bedtimes, screen-free wind-downs, and your daily lessons.")
                    .foregroundStyle(.secondary)
            }

            Section("Tips") {
                Label("Aim for 7–9 hours", systemImage: "moon.zzz.fill")
                Label("Keep bedtime consistent", systemImage: "alarm")
                Label("Limit screens 1 hour before bed", systemImage: "tv.and.hifispeaker.fill")
            }

            Section("Next steps") {
                Text("We’ll notify you when detailed sleep tracking lands. In the meantime, log how you feel each morning to spot patterns.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Sleep locked")
                .font(.title3.weight(.semibold))
            Text("Complete Sleep & Recovery to enable sleep insights.")
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
                    showLearnAlert = true
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    SleepInsightsView()
        .environmentObject(ContentStore())
}
