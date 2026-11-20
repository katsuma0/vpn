import Foundation

/// Your servers and which country you picked. The VPN itself lives in
/// `VPNController`; this type just decides what to connect to.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published var selectedCountryCode: String? = nil {
        didSet { UserDefaults.standard.set(selectedCountryCode, forKey: Self.selectedKey) }
    }

    private let library: ServerLibrary
    private static let selectedKey = "selectedCountry"

    init(library: ServerLibrary? = nil) {
        let library = library ?? ServerLibrary(fileURL: ServerLibrary.defaultFileURL())
        self.library = library
        self.servers = library.servers
        self.selectedCountryCode = UserDefaults.standard.string(forKey: Self.selectedKey)
        fixSelection()
    }

    var countries: [CountrySummary] { library.countries }
    var missingCountries: [Country] { library.missingCountries }

    var selectedCountry: Country? {
        selectedCountryCode.map { Country.with(code: $0) }
    }

    var selectedServer: Server? {
        selectedCountryCode.flatMap { library.server(for: $0) }
    }

    func servers(in countryCode: String) -> [Server] {
        library.servers(in: countryCode)
    }

    func server(id: UUID?) -> Server? {
        guard let id else { return nil }
        return servers.first { $0.id == id }
    }

    func add(_ draft: ServerDraft) throws {
        let server = try library.add(draft)
        servers = library.servers
        if selectedServer == nil { selectedCountryCode = server.countryCode }
    }

    func update(_ server: Server) throws {
        try library.update(server)
        servers = library.servers
        fixSelection()
    }

    func remove(_ server: Server) throws {
        try library.remove(id: server.id)
        servers = library.servers
        fixSelection()
    }

    // MARK: Actions

    func toggle(_ vpn: VPNController) async {
        if vpn.phase == .off {
            await connect(vpn)
        } else {
            vpn.disconnect()
        }
    }

    func connect(_ vpn: VPNController) async {
        guard let server = selectedServer else {
            vpn.errorMessage = "Add a server first. Tap Servers, then Add Server."
            return
        }
        await vpn.connect(to: server)
    }

    /// Picks a country. If you're already connected, Hop hops straight over.
    func select(_ countryCode: String, vpn: VPNController) async {
        selectedCountryCode = countryCode
        if vpn.phase != .off {
            await connect(vpn)
        }
    }

    private func fixSelection() {
        if selectedServer == nil {
            selectedCountryCode = library.countries.first?.country.code
        }
    }
}
