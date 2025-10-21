import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: FastingHistoryStore
    @State private var sessionPendingDeletion: FastingSession?
    @State private var showDeleteConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var shareText: String = ""
    @State private var showShareSheet = false

    private var hoursLast7: Double {
        historyStore.totalDuration(hoursWithin: 7)
    }

    private var hoursLast30: Double {
        historyStore.totalDuration(hoursWithin: 30)
    }

    var body: some View {
        List {
            statsSection

            if historyStore.sessions.isEmpty {
                emptyState
            } else {
                sessionsSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Fasting History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showClearAllConfirmation = true
                    } label: {
                        Label("Clear all history", systemImage: "trash")
                    }

                    Button {
                        shareText = buildShareText()
                        showShareSheet = true
                    } label: {
                        Label("Export summary", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Remove this fasting session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pending = sessionPendingDeletion {
                    historyStore.remove(pending.id)
                }
            }
            Button("Cancel", role: .cancel) {
                sessionPendingDeletion = nil
            }
        }
        .confirmationDialog(
            "Clear all fasting history?",
            isPresented: $showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                historyStore.removeAll()
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showShareSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fasting Summary")
                        .font(.headline)
                    ScrollView {
                        Text(shareText.isEmpty ? "No sessions to export." : shareText)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showShareSheet = false
                        }
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(formattedHours(hoursLast7)) hours fasted")
                    .font(.headline)

                Divider()

                Text("Last 30 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(formattedHours(hoursLast30)) hours fasted")
                    .font(.headline)
            }
            .padding(.vertical, 4)
        }
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            ForEach(historyStore.sessions) { session in
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.start.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(durationString(seconds: session.durationSeconds))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        sessionPendingDeletion = session
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Section {
            Text("Your fasts will appear here.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        }
    }

    private func formattedHours(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func durationString(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, remainingSeconds)
        }
    }

    private func buildShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var lines: [String] = [
            "Fasting History Export",
            "Generated \(Date().formatted(date: .abbreviated, time: .shortened))",
            ""
        ]

        if historyStore.sessions.isEmpty {
            lines.append("No sessions recorded.")
        } else {
            for session in historyStore.sessions {
                let startLine = formatter.string(from: session.start)
                let endLine = formatter.string(from: session.end)
                let duration = durationString(seconds: session.durationSeconds)
                lines.append("\(startLine) – \(endLine)  (\(duration))")
            }
        }

        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject({
                let store = FastingHistoryStore()
                store.append(start: Date().addingTimeInterval(-7200), end: Date().addingTimeInterval(-3600))
                return store
            }())
    }
}
