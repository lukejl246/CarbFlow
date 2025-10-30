import Foundation
import Network
import Combine

// MARK: - Connection Type

enum ConnectionType: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case wired = "Wired"
    case none = "None"
}

// MARK: - Network Monitor

/// Monitors network connectivity using NWPathMonitor
/// Published properties for SwiftUI binding and Combine reactive updates
@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Published Properties

    /// Whether device is connected to internet
    @Published private(set) var isConnected: Bool = false

    /// Type of connection (WiFi, cellular, none)
    @Published private(set) var connectionType: ConnectionType = .none

    /// Whether device was previously offline and just reconnected
    @Published private(set) var didReconnect: Bool = false

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.carbflow.networkmonitor")

    /// Debounce timer to prevent rapid updates
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 2.0

    /// Track last connection state for reconnection detection
    private var wasConnected: Bool = false

    /// Pending connection state (before debounce)
    private var pendingIsConnected: Bool?
    private var pendingConnectionType: ConnectionType?

    // MARK: - Initialization

    init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
        debounceTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newIsConnected = path.status == .satisfied
            let newConnectionType = Self.determineConnectionType(from: path)

            // Debounce rapid changes
            Task { @MainActor in
                self.handlePathUpdate(
                    isConnected: newIsConnected,
                    connectionType: newConnectionType
                )
            }
        }

        monitor.start(queue: monitorQueue)
    }

    /// Stop monitoring network changes
    func stopMonitoring() {
        monitor.cancel()
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    // MARK: - Private Methods

    private func handlePathUpdate(isConnected: Bool, connectionType: ConnectionType) {
        // Store pending values
        pendingIsConnected = isConnected
        pendingConnectionType = connectionType

        // Cancel existing timer
        debounceTimer?.invalidate()

        // Start debounce timer
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyPendingUpdate()
            }
        }
    }

    private func applyPendingUpdate() {
        guard let newIsConnected = pendingIsConnected,
              let newConnectionType = pendingConnectionType else {
            return
        }

        // Detect reconnection (was offline, now online)
        let isReconnecting = !wasConnected && newIsConnected

        // Update published properties
        self.isConnected = newIsConnected
        self.connectionType = newConnectionType
        self.didReconnect = isReconnecting

        // Track previous state
        wasConnected = newIsConnected

        // Clear pending values
        pendingIsConnected = nil
        pendingConnectionType = nil

        // Reset reconnection flag after notification
        if isReconnecting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.didReconnect = false
            }
        }
    }

    private nonisolated static func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.status != .satisfied {
            return .none
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .none
        }
    }
}

// MARK: - Singleton

extension NetworkMonitor {
    /// Shared singleton instance for app-wide access
    static let shared = NetworkMonitor()
}

// MARK: - Convenience Properties

extension NetworkMonitor {

    /// Human-readable connection status
    var connectionStatus: String {
        if isConnected {
            return "Connected via \(connectionType.rawValue)"
        } else {
            return "Offline"
        }
    }

    /// Whether connected via WiFi specifically
    var isConnectedViaWiFi: Bool {
        return isConnected && connectionType == .wifi
    }

    /// Whether connected via cellular specifically
    var isConnectedViaCellular: Bool {
        return isConnected && connectionType == .cellular
    }
}
