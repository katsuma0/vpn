import Foundation

extension WireGuardConfig {
    /// Turns our parsed config into the types WireGuardKit runs on.
    func makeTunnelConfiguration(name: String?) throws -> TunnelConfiguration {
        guard let privateKey = PrivateKey(base64Key: interface.privateKey) else {
            throw WireGuardConfigError.invalidKey(field: "PrivateKey")
        }
        var wgInterface = InterfaceConfiguration(privateKey: privateKey)
        wgInterface.addresses = try interface.addresses.map { try Self.range($0, field: "Address") }
        for entry in interface.dns {
            if let server = DNSServer(from: entry) {
                wgInterface.dns.append(server)
            } else {
                wgInterface.dnsSearch.append(entry)
            }
        }
        wgInterface.mtu = interface.mtu
        wgInterface.listenPort = interface.listenPort

        let wgPeers: [PeerConfiguration] = try peers.map { peer in
            guard let publicKey = PublicKey(base64Key: peer.publicKey) else {
                throw WireGuardConfigError.invalidKey(field: "PublicKey")
            }
            var wgPeer = PeerConfiguration(publicKey: publicKey)
            if let psk = peer.preSharedKey {
                guard let key = PreSharedKey(base64Key: psk) else {
                    throw WireGuardConfigError.invalidKey(field: "PresharedKey")
                }
                wgPeer.preSharedKey = key
            }
            wgPeer.allowedIPs = try peer.allowedIPs.map { try Self.range($0, field: "AllowedIPs") }
            if let endpoint = peer.endpoint {
                guard let parsed = Endpoint(from: endpoint) else {
                    throw WireGuardConfigError.invalidValue(field: "Endpoint", value: endpoint)
                }
                wgPeer.endpoint = parsed
            }
            wgPeer.persistentKeepAlive = peer.persistentKeepalive
            return wgPeer
        }

        return TunnelConfiguration(name: name, interface: wgInterface, peers: wgPeers)
    }

    private static func range(_ value: String, field: String) throws -> IPAddressRange {
        guard let range = IPAddressRange(from: value) else {
            throw WireGuardConfigError.invalidValue(field: field, value: value)
        }
        return range
    }
}
