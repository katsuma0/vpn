import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// A parsed WireGuard config in the standard wg-quick format, the `.conf`
/// file every WireGuard provider hands out.
struct WireGuardConfig: Equatable {
    struct Interface: Equatable {
        var privateKey: String
        var addresses: [String] = []
        var dns: [String] = []
        var mtu: UInt16?
        var listenPort: UInt16?
    }

    struct Peer: Equatable {
        var publicKey: String
        var preSharedKey: String?
        var allowedIPs: [String] = []
        var endpoint: String?
        var persistentKeepalive: UInt16?
        /// Comments written inside the `[Peer]` block. Providers often put
        /// the server name here ("# US-FREE#12").
        var comments: [String] = []
    }

    var interface: Interface
    var peers: [Peer]

    /// The endpoint of the first peer, the server you actually talk to.
    var primaryEndpoint: String? {
        peers.first(where: { $0.endpoint != nil })?.endpoint
    }

    /// Host part of `primaryEndpoint`, without port or IPv6 brackets.
    var primaryHost: String? {
        guard let endpoint = primaryEndpoint else { return nil }
        return WireGuardConfig.splitEndpoint(endpoint)?.host
    }
}

enum WireGuardConfigError: LocalizedError, Equatable {
    case empty
    case missingInterface
    case missingPrivateKey
    case noPeers
    case missingPublicKey
    case missingEndpoint
    case duplicatePeer
    case invalidKey(field: String)
    case invalidValue(field: String, value: String)
    case unknownSection(String)
    case badLine(Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "That file is empty. Pick a WireGuard .conf file."
        case .missingInterface:
            return "This doesn't look like a WireGuard config. It needs an [Interface] section."
        case .missingPrivateKey:
            return "The config has no PrivateKey, so it can't connect."
        case .noPeers:
            return "The config has no [Peer] section, so there's no server to connect to."
        case .missingPublicKey:
            return "A [Peer] section is missing its PublicKey."
        case .missingEndpoint:
            return "The config doesn't say which server to reach. Add an Endpoint to the [Peer] section."
        case .duplicatePeer:
            return "The same peer appears twice in this config."
        case .invalidKey(let field):
            return "The \(field) isn't a valid WireGuard key."
        case .invalidValue(let field, let value):
            return "\(field) has a value WireGuard can't use: \(value)"
        case .unknownSection(let name):
            return "Unknown section [\(name)]. WireGuard configs only have [Interface] and [Peer]."
        case .badLine(let number):
            return "Line \(number) isn't in the \"Key = Value\" format."
        }
    }
}

extension WireGuardConfig {
    /// Keys wg-quick understands that make no sense on iPhone or Mac.
    /// We skip them instead of refusing a config someone copied from Linux.
    private static let ignoredKeys: Set<String> = [
        "table", "preup", "postup", "predown", "postdown", "saveconfig", "fwmark",
    ]

    static func parse(_ text: String) throws -> WireGuardConfig {
        enum Section { case none, interface, peer }

        var section = Section.none
        var sawInterface = false
        var privateKey: String?
        var addresses: [String] = []
        var dns: [String] = []
        var mtu: UInt16?
        var listenPort: UInt16?
        var peers: [Peer] = []
        var draft: Peer?

        func finishPeer() throws {
            guard let peer = draft else { return }
            guard !peer.publicKey.isEmpty else { throw WireGuardConfigError.missingPublicKey }
            peers.append(peer)
            draft = nil
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw WireGuardConfigError.empty
        }

        for (index, rawLine) in lines.enumerated() {
            var line = rawLine
            var comment: String?
            if let hash = line.firstIndex(of: "#") {
                let note = line[line.index(after: hash)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !note.isEmpty { comment = note }
                line = String(line[..<hash])
            }
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            defer {
                if section == .peer, let comment { draft?.comments.append(comment) }
            }
            if line.isEmpty { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                try finishPeer()
                switch name.lowercased() {
                case "interface":
                    section = .interface
                    sawInterface = true
                case "peer":
                    section = .peer
                    draft = Peer(publicKey: "")
                default:
                    throw WireGuardConfigError.unknownSection(name)
                }
                continue
            }

            guard let equals = line.firstIndex(of: "=") else {
                throw WireGuardConfigError.badLine(index + 1)
            }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            let lowerKey = key.lowercased()
            if ignoredKeys.contains(lowerKey) { continue }

            switch section {
            case .none:
                throw WireGuardConfigError.missingInterface
            case .interface:
                switch lowerKey {
                case "privatekey":
                    guard isValidKey(value) else { throw WireGuardConfigError.invalidKey(field: "PrivateKey") }
                    privateKey = value
                case "address":
                    let items = list(value)
                    for item in items where !isValidRange(item) {
                        throw WireGuardConfigError.invalidValue(field: "Address", value: item)
                    }
                    addresses += items
                case "dns":
                    dns += list(value)
                case "mtu":
                    guard let parsed = UInt16(value), parsed >= 576 else {
                        throw WireGuardConfigError.invalidValue(field: "MTU", value: value)
                    }
                    mtu = parsed
                case "listenport":
                    guard let parsed = UInt16(value) else {
                        throw WireGuardConfigError.invalidValue(field: "ListenPort", value: value)
                    }
                    listenPort = parsed
                default:
                    throw WireGuardConfigError.invalidValue(field: key, value: value)
                }
            case .peer:
                switch lowerKey {
                case "publickey":
                    guard isValidKey(value) else { throw WireGuardConfigError.invalidKey(field: "PublicKey") }
                    draft?.publicKey = value
                case "presharedkey":
                    guard isValidKey(value) else { throw WireGuardConfigError.invalidKey(field: "PresharedKey") }
                    draft?.preSharedKey = value
                case "allowedips":
                    let items = list(value)
                    for item in items where !isValidRange(item) {
                        throw WireGuardConfigError.invalidValue(field: "AllowedIPs", value: item)
                    }
                    draft?.allowedIPs += items
                case "endpoint":
                    guard splitEndpoint(value) != nil else {
                        throw WireGuardConfigError.invalidValue(field: "Endpoint", value: value)
                    }
                    draft?.endpoint = value
                case "persistentkeepalive":
                    if value.lowercased() == "off" {
                        draft?.persistentKeepalive = nil
                    } else if let seconds = UInt16(value) {
                        draft?.persistentKeepalive = seconds == 0 ? nil : seconds
                    } else {
                        throw WireGuardConfigError.invalidValue(field: "PersistentKeepalive", value: value)
                    }
                default:
                    throw WireGuardConfigError.invalidValue(field: key, value: value)
                }
            }
        }
        try finishPeer()

        guard sawInterface else { throw WireGuardConfigError.missingInterface }
        guard let key = privateKey else { throw WireGuardConfigError.missingPrivateKey }
        guard !peers.isEmpty else { throw WireGuardConfigError.noPeers }
        guard peers.contains(where: { $0.endpoint != nil }) else { throw WireGuardConfigError.missingEndpoint }
        guard Set(peers.map(\.publicKey)).count == peers.count else { throw WireGuardConfigError.duplicatePeer }

        let interface = Interface(
            privateKey: key,
            addresses: addresses,
            dns: dns,
            mtu: mtu,
            listenPort: listenPort
        )
        return WireGuardConfig(interface: interface, peers: peers)
    }

    // MARK: - Validation helpers

    /// Splits "host:port" or "[v6]:port" into its parts.
    static func splitEndpoint(_ value: String) -> (host: String, port: UInt16)? {
        let host: Substring
        let portText: Substring
        if value.hasPrefix("[") {
            guard let close = value.firstIndex(of: "]") else { return nil }
            host = value[value.index(after: value.startIndex)..<close]
            let rest = value[value.index(after: close)...]
            guard rest.hasPrefix(":") else { return nil }
            portText = rest.dropFirst()
        } else {
            guard let colon = value.lastIndex(of: ":") else { return nil }
            host = value[..<colon]
            portText = value[value.index(after: colon)...]
            // A bare IPv6 address without brackets is ambiguous.
            if host.contains(":") { return nil }
        }
        guard !host.isEmpty, !host.contains(" "), let port = UInt16(portText), port > 0 else { return nil }
        return (String(host), port)
    }

    /// WireGuard keys are 32 bytes, written as 44 characters of base64.
    static func isValidKey(_ value: String) -> Bool {
        guard value.count == 44, let data = Data(base64Encoded: value) else { return false }
        return data.count == 32
    }

    /// Accepts "10.0.0.2", "10.0.0.2/32", "fd00::2/128" and friends.
    static func isValidRange(_ value: String) -> Bool {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return false }
        let address = String(parts[0])
        let isV4 = isIPv4(address)
        let isV6 = !isV4 && isIPv6(address)
        guard isV4 || isV6 else { return false }
        if parts.count == 2 {
            guard let prefix = UInt8(parts[1]) else { return false }
            return prefix <= (isV4 ? 32 : 128)
        }
        return true
    }

    static func isIPv4(_ value: String) -> Bool {
        var addr = in_addr()
        return value.withCString { inet_pton(AF_INET, $0, &addr) } == 1
    }

    static func isIPv6(_ value: String) -> Bool {
        var addr = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &addr) } == 1
    }

    private static func list(_ value: String) -> [String] {
        value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
