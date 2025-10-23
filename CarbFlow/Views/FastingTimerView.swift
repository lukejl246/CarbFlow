import SwiftUI
import Combine

struct FastingTimerView: View {
    @AppStorage(Keys.currentDay) private var currentDay = 1
    @AppStorage(Keys.isFasting) private var isFasting = false
    @AppStorage(Keys.fastingStart) private var fastingStart = 0.0
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject private var historyStore: FastingHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var fastingUnlockDay: Int {
        contentStore.days.first {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveContains("Meal Timing")
        }?.day ?? 5
    }

    private var isUnlocked: Bool {
        currentDay > fastingUnlockDay
    }

    private var elapsed: TimeInterval {
        guard isFasting, fastingStart > 0 else { return 0 }
        return max(now.timeIntervalSince1970 - fastingStart, 0)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Group {
            if isUnlocked {
                ScrollView {
                    VStack(spacing: 20) {
                        timerCard
                        historyCard
                        NavigationLink {
                            HistoryView()
                                .environmentObject(historyStore)
                        } label: {
                            Label("View history", systemImage: "clock.arrow.circlepath")
                                .font(.footnote)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.7)))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            } else {
                lockedContent
            }
        }
        .background(backgroundGradient.ignoresSafeArea())
        .alert("Learn Meal Timing", isPresented: $showLearnAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text("Switch to the Learn tab and complete Meal Timing to unlock fasting.")
        })
    }

    private var timerCard: some View {
        TimerCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Fasting timer", systemImage: "bolt.heart")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text(format(elapsed))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .onReceive(timer) { date in
                        now = date
                    }

                if isFasting {
                    Button(role: .destructive, action: endFast) {
                        Text("End Fast")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .cornerRadius(14)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not fasting right now.")
                            .foregroundColor(.secondary)

                        Button(action: startFast) {
                            Text("Start Fast")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        TimerCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recent sessions", systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if recentSessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("No fasting sessions recorded yet.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    summaryChip
                    VStack(spacing: 10) {
                        ForEach(recentSessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private func startFast() {
        fastingStart = Date().timeIntervalSince1970
        isFasting = true
    }

    private func endFast() {
        guard fastingStart > 0 else {
            isFasting = false
            return
        }
        let startDate = Date(timeIntervalSince1970: fastingStart)
        let endDate = Date()
        historyStore.append(start: startDate, end: endDate)
        fastingStart = 0
        isFasting = false
    }

    private func format(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var recentSessions: [FastingSession] {
        Array(historyStore.sessions.prefix(5))
    }

    private var totalHoursLast7Days: Double {
        historyStore.totalDuration(hoursWithin: 7)
    }

    private func sessionRow(_ session: FastingSession) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.start.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.footnote)
                    .foregroundColor(.primary)
                Text("Ended \(session.end.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(session.durationSeconds))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("\(format(TimeInterval(session.durationSeconds)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private var summaryChip: some View {
        let hours = totalHoursLast7Days
        let formatted = hours >= 1 ? String(format: "%.1f h", hours) : String(format: "%.0f m", hours * 60)
        return HStack {
            Label("Last 7 days", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text(formatted)
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.accentColor.opacity(0.12))
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Fasting locked")
                .font(.title3.weight(.semibold))
            Text("Complete Meal Timing to enable the fasting timer.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
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
        .background(backgroundGradient.ignoresSafeArea())
    }

    @State private var showLearnAlert = false

    private struct TimerCard<Content: View>: View {
        private let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: Color.black.opacity(0.035), radius: 12, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

#Preview {
    FastingTimerView()
        .environmentObject(ContentStore())
        .environmentObject(FastingHistoryStore())
}
