import Foundation
import NetworkExtension

/// Talks to the system VPN settings. One VPN profile named "Hop" is created
/// the first time you connect, and reused after that.
@MainActor
final class VPNController: ObservableObject {
    enum Phase: Equatable {
        case off, connecting, on, disconnecting
    }

    @Published private(set) var phase: Phase = .off
    @Published private(set) var connectedSince: Date? = nil
    @Published private(set) var activeServerID: UUID? = nil
    @Published var errorMessage: String? = nil

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var lastStatus: NEVPNStatus = .invalid
    private var userRequestedStop = false

    /// The extension's bundle ID is always the app's plus ".tunnel".
    private var tunnelBundleID: String {
        (Bundle.main.bundleIdentifier ?? "hop") + ".tunnel"
    }

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.statusChanged() }
        }
        Task { await loadManager() }
    }

    func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelBundleID
            }) ?? managers.first
            statusChanged()
        } catch {
            errorMessage = "Couldn't read your VPN settings. \(error.localizedDescription)"
        }
    }

    func connect(to server: Server) async {
        errorMessage = nil
        do {
            let parsed = try WireGuardConfig.parse(server.config)
            let manager = self.manager ?? NETunnelProviderManager()

            // Switching countries while connected: stop first, then start fresh.
            let status = manager.connection.status
            if status != .disconnected && status != .invalid {
                userRequestedStop = true
                manager.connection.stopVPNTunnel()
                await waitUntilStopped(manager)
            }

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = tunnelBundleID
            proto.serverAddress = parsed.primaryEndpoint ?? server.name
            proto.providerConfiguration = [
                TunnelKeys.config: server.config,
                TunnelKeys.serverID: server.id.uuidString,
            ]
            manager.protocolConfiguration = proto
            manager.localizedDescription = "Hop"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            // Load again after saving, or the very first start can fail.
            try await manager.loadFromPreferences()
            self.manager = manager

            userRequestedStop = false
            activeServerID = server.id
            try manager.connection.startVPNTunnel()
            statusChanged()
        } catch {
            errorMessage = VPNController.friendly(error)
        }
    }

    func disconnect() {
        userRequestedStop = true
        manager?.connection.stopVPNTunnel()
    }

    // MARK: - Private

    private func waitUntilStopped(_ manager: NETunnelProviderManager) async {
        for _ in 0..<50 {
            let status = manager.connection.status
            if status == .disconnected || status == .invalid { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func statusChanged() {
        guard let manager else {
            phase = .off
            connectedSince = nil
            return
        }
        let status = manager.connection.status
        switch status {
        case .connecting, .reasserting:
            phase = .connecting
        case .connected:
            phase = .on
        case .disconnecting:
            phase = .disconnecting
        case .disconnected, .invalid:
            phase = .off
        @unknown default:
            phase = .off
        }
        connectedSince = status == .connected ? manager.connection.connectedDate : nil

        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol
        if let id = proto?.providerConfiguration?[TunnelKeys.serverID] as? String {
            activeServerID = UUID(uuidString: id)
        }

        // The tunnel dropped without you asking. Find out why and say so.
        let wasUp = lastStatus == .connecting || lastStatus == .connected || lastStatus == .reasserting
        if status == .disconnected && wasUp && !userRequestedStop {
            manager.connection.fetchLastDisconnectError { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.errorMessage = VPNController.friendly(error)
                }
            }
        }
        if status == .disconnected { userRequestedStop = false }
        lastStatus = status
    }

    static func friendly(_ error: Error) -> String {
        if let vpnError = error as? NEVPNError {
            switch vpnError.code {
            case .configurationReadWriteFailed:
                return "Hop couldn't save its VPN profile. If you tapped Don't Allow, tap Connect again and choose Allow."
            case .configurationDisabled, .configurationStale:
                return "The VPN profile was turned off in Settings. Tap Connect to turn it back on."
            case .configurationInvalid:
                return "The VPN profile is broken. Delete Hop in Settings > VPN and connect again."
            case .connectionFailed:
                return "Couldn't reach the server. Try another country or check your internet."
            default:
                break
            }
        }
        let nsError = error as NSError
        if nsError.domain == "NEVPNConnectionErrorDomain" {
            return "The connection dropped. The server may be down or the config may be out of date. Try another server."
        }
        return error.localizedDescription
    }
}
