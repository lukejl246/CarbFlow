import SwiftUI

// MARK: - Cache Status State

enum CacheStatusState: Equatable {
    case hidden
    case info(productCount: Int)
    case syncing(current: Int, total: Int)
    case success(message: String)
    case error(message: String)
}

// MARK: - Cache Status View

/// Small status card showing cache/sync status at top of scanner
struct CacheStatusView: View {

    @ObservedObject var syncCoordinator: UPCSyncCoordinator
    @State private var currentState: CacheStatusState = .hidden
    @State private var autoHideTask: Task<Void, Never>?

    private let isEnabled: Bool

    init(syncCoordinator: UPCSyncCoordinator) {
        self.syncCoordinator = syncCoordinator
        self.isEnabled = FeatureFlags.cf_scancache
    }

    init() {
        self.syncCoordinator = UPCSyncCoordinator.shared
        self.isEnabled = FeatureFlags.cf_scancache
    }

    var body: some View {
        Group {
            if isEnabled {
                statusCard
                    .frame(height: cardHeight)
                    .animation(.easeInOut(duration: 0.3), value: currentState)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: syncCoordinator.isSyncing) { _, isSyncing in
            updateState()
        }
        .onChange(of: syncCoordinator.syncProgress) { _, _ in
            updateState()
        }
        .onChange(of: syncCoordinator.lastSyncResult) { _, _ in
            updateState()
        }
        .onAppear {
            updateState()
        }
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        if !isHidden {
            HStack(spacing: 10) {
                // Icon
                statusIcon
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(statusColor)

                // Text
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.primary)

                Spacer()

                // Retry button for error state
                if case .error = currentState {
                    Button {
                        Task {
                            await syncCoordinator.forceSyncNow()
                        }
                    } label: {
                        Text("Retry")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - State Helpers

    private var isHidden: Bool {
        if case .hidden = currentState {
            return true
        }
        return false
    }

    private var cardHeight: CGFloat {
        isHidden ? 0 : 44
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch currentState {
        case .hidden:
            EmptyView()
        case .info:
            Image(systemName: "checkmark.circle.fill")
        case .syncing:
            ProgressView()
                .scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var statusColor: Color {
        switch currentState {
        case .hidden:
            return .clear
        case .info:
            return .accentColor
        case .syncing:
            return .accentColor
        case .success:
            return .green
        case .error:
            return .orange
        }
    }

    private var statusText: String {
        switch currentState {
        case .hidden:
            return ""
        case .info(let count):
            return "\(count) products cached"
        case .syncing(let current, let total):
            return "Syncing... \(current)/\(total)"
        case .success(let message):
            return message
        case .error(let message):
            return message
        }
    }

    // MARK: - State Management

    private func updateState() {
        // Cancel any pending auto-hide
        autoHideTask?.cancel()

        // Determine new state
        if syncCoordinator.isSyncing {
            // Syncing state
            if let progress = syncCoordinator.syncProgress {
                currentState = .syncing(
                    current: progress.current,
                    total: progress.total
                )
            } else {
                currentState = .syncing(current: 0, total: 0)
            }
        } else if let result = syncCoordinator.lastSyncResult {
            // Check if sync just completed
            if let lastSyncTime = syncCoordinator.lastSyncTime,
               Date().timeIntervalSince(lastSyncTime) < 1.0 {

                // Show result
                if result.successful.isEmpty && result.failed.isEmpty {
                    currentState = .hidden
                } else if !result.successful.isEmpty {
                    // Success state
                    currentState = .success(message: "Cache updated")

                    // Auto-hide after 3s
                    autoHideTask = Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                        await MainActor.run {
                            currentState = .hidden
                        }
                    }
                } else if !result.errors.isEmpty {
                    // Error state
                    currentState = .error(message: "Sync failed")
                } else {
                    currentState = .hidden
                }
            } else {
                currentState = .hidden
            }
        } else {
            currentState = .hidden
        }
    }
}

// MARK: - Preview

#Preview("Info State") {
    VStack {
        CacheStatusView(syncCoordinator: {
            let coordinator = UPCSyncCoordinator()
            return coordinator
        }())

        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Syncing State") {
    VStack {
        CacheStatusView(syncCoordinator: {
            let coordinator = UPCSyncCoordinator()
            // Note: In real usage, coordinator would be syncing
            return coordinator
        }())

        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}
