import NetworkExtension
import os

private let tunnelLog = Logger(subsystem: "Hop", category: "tunnel")

/// The part that actually moves your traffic. iOS and macOS launch it in its
/// own process when you tap Connect, and it hands packets to WireGuard.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { level, message in
            switch level {
            case .error:
                tunnelLog.error("\(message, privacy: .public)")
            default:
                tunnelLog.debug("\(message, privacy: .public)")
            }
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let configuration: TunnelConfiguration
        do {
            guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
                  let text = proto.providerConfiguration?[TunnelKeys.config] as? String else {
                throw TunnelError.missingConfiguration
            }
            configuration = try WireGuardConfig.parse(text).makeTunnelConfiguration(name: proto.serverAddress)
        } catch {
            tunnelLog.error("Bad config: \(error.localizedDescription, privacy: .public)")
            completionHandler(error)
            return
        }

        adapter.start(tunnelConfiguration: configuration) { adapterError in
            if let adapterError {
                tunnelLog.error("Start failed: \(String(describing: adapterError), privacy: .public)")
                completionHandler(TunnelError.adapter(adapterError))
            } else {
                tunnelLog.info("Tunnel is up")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { _ in
            completionHandler()
        }
    }
}

enum TunnelError: LocalizedError {
    case missingConfiguration
    case adapter(WireGuardAdapterError)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "The tunnel started without a server config. Pick a country and try again."
        case .adapter(let error):
            switch error {
            case .cannotLocateTunnelFileDescriptor:
                return "The system didn't hand over a network interface. Try again."
            case .invalidState:
                return "The tunnel was busy. Try again in a moment."
            case .dnsResolution:
                return "Couldn't look up the server's address. Check your internet connection."
            case .setNetworkSettings:
                return "The system refused the VPN network settings."
            case .startWireGuardBackend(let code):
                return "WireGuard failed to start (code \(code))."
            }
        }
    }
}
