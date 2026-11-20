import Foundation

/// One WireGuard server you've added.
struct Server: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var countryCode: String
    /// The full wg-quick config text, exactly as imported.
    var config: String
    var addedAt: Date

    var country: Country { Country.with(code: countryCode) }

    /// "203.0.113.7:51820", shown under the server name.
    var endpoint: String? { (try? WireGuardConfig.parse(config))?.primaryEndpoint }
}

/// A country plus how many of your servers live there.
struct CountrySummary: Identifiable, Hashable {
    let country: Country
    let serverCount: Int

    var id: String { country.code }
}

/// A config that's been read and checked, waiting for you to confirm it.
struct ServerDraft: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var countryCode: String
    var config: String
}

enum ServerLibraryError: LocalizedError, Equatable {
    case duplicate(name: String)

    var errorDescription: String? {
        switch self {
        case .duplicate(let name):
            return "You already added this server as \"\(name)\"."
        }
    }
}

/// Your saved servers. Plain Swift with no UI code, so it's easy to test.
final class ServerLibrary {
    private(set) var servers: [Server]
    private let fileURL: URL?

    /// Pass nil to keep everything in memory (handy for previews and tests).
    init(fileURL: URL?) {
        self.fileURL = fileURL
        self.servers = []
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            servers = (try? JSONDecoder().decode([Server].self, from: data)) ?? []
        }
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hop", isDirectory: true)
            .appendingPathComponent("servers.json")
    }

    // MARK: Reading configs

    /// Parses config text and guesses a name and country for it.
    /// Throws a friendly error if the config can't work.
    static func makeDraft(config text: String, fileName: String? = nil) throws -> ServerDraft {
        let parsed = try WireGuardConfig.parse(text)
        let baseName = fileName.map { ($0 as NSString).deletingPathExtension }
        let peerComment = parsed.peers.first?.comments.first(where: { looksLikeName($0) })

        var hints: [String] = []
        if let baseName { hints.append(baseName) }
        if let peerComment { hints.append(peerComment) }
        if let host = parsed.primaryHost { hints.append(host) }
        let code = CountryDetector.detect(in: hints) ?? Country.otherCode

        let name = peerComment ?? baseName ?? parsed.primaryHost ?? "WireGuard server"
        return ServerDraft(name: name, countryCode: code, config: text)
    }

    /// Comments like "Bouncing = 7" are settings, not names.
    private static func looksLikeName(_ comment: String) -> Bool {
        !comment.contains("=") && comment.count <= 40
    }

    // MARK: Changing the list

    @discardableResult
    func add(_ draft: ServerDraft, now: Date = Date()) throws -> Server {
        let normalized = Self.normalize(draft.config)
        if let existing = servers.first(where: { Self.normalize($0.config) == normalized }) {
            throw ServerLibraryError.duplicate(name: existing.name)
        }
        _ = try WireGuardConfig.parse(draft.config)
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let server = Server(
            id: UUID(),
            name: trimmedName.isEmpty ? "WireGuard server" : trimmedName,
            countryCode: draft.countryCode,
            config: draft.config,
            addedAt: now
        )
        servers.append(server)
        try save()
        return server
    }

    func update(_ server: Server) throws {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        try save()
    }

    func remove(id: UUID) throws {
        servers.removeAll { $0.id == id }
        try save()
    }

    // MARK: Looking things up

    /// Countries you have at least one server for, in the app's usual order.
    var countries: [CountrySummary] {
        let grouped = Dictionary(grouping: servers, by: { $0.countryCode.uppercased() })
        return grouped
            .map { CountrySummary(country: Country.with(code: $0.key), serverCount: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.country.sortIndex != rhs.country.sortIndex {
                    return lhs.country.sortIndex < rhs.country.sortIndex
                }
                return lhs.country.name < rhs.country.name
            }
    }

    /// Major countries you don't have a server for yet.
    var missingCountries: [Country] {
        let have = Set(servers.map { $0.countryCode.uppercased() })
        return Country.major.filter { !have.contains($0.code) }
    }

    /// The server to use for a country: the oldest one you added there.
    func server(for countryCode: String) -> Server? {
        servers
            .filter { $0.countryCode.caseInsensitiveCompare(countryCode) == .orderedSame }
            .min { $0.addedAt < $1.addedAt }
    }

    func servers(in countryCode: String) -> [Server] {
        servers
            .filter { $0.countryCode.caseInsensitiveCompare(countryCode) == .orderedSame }
            .sorted { $0.addedAt < $1.addedAt }
    }

    // MARK: Saving

    private func save() throws {
        guard let fileURL else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(servers)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    private static func normalize(_ config: String) -> String {
        config
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
