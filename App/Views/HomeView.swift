import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var vpn: VPNController
    @State private var sheet: Sheet? = nil

    enum Sheet: String, Identifiable {
        case countries, servers, addServer, help
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 8)
                header
                ConnectButton(phase: vpn.phase, isEnabled: canTap) {
                    Task { await model.toggle(vpn) }
                }
                timer
                Spacer(minLength: 8)
                if model.servers.isEmpty {
                    emptyCard
                } else {
                    locationButton
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .navigationTitle("Hop")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .servers
                    } label: {
                        Label("Servers", systemImage: "list.bullet")
                    }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .countries: CountryPickerView().sheetChrome(model, vpn)
                case .servers: ServersView().sheetChrome(model, vpn)
                case .addServer: AddServerView().sheetChrome(model, vpn)
                case .help: HelpView().sheetChrome(model, vpn)
                }
            }
            .alert("Something went wrong", isPresented: errorShown) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vpn.errorMessage ?? "")
            }
        }
    }

    // MARK: Pieces

    private var canTap: Bool {
        vpn.phase != .off || model.selectedServer != nil
    }

    /// The country you're actually tunneled through, falling back to the one you picked.
    private var shownCountry: Country? {
        if vpn.phase != .off, let active = model.server(id: vpn.activeServerID) {
            return active.country
        }
        return model.selectedCountry
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(.title2.weight(.bold))
            Text(subheadline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .animation(.default, value: vpn.phase)
    }

    private var headline: String {
        switch vpn.phase {
        case .off: return "You're not protected"
        case .connecting: return "Connecting..."
        case .on: return "You're protected"
        case .disconnecting: return "Disconnecting..."
        }
    }

    private var subheadline: String {
        let name = shownCountry?.name
        switch vpn.phase {
        case .on:
            return name.map { "Sites now see you in \($0)." } ?? "Your traffic is going through the VPN."
        case .connecting:
            return name.map { "Hopping to \($0)." } ?? "Hang tight."
        case .disconnecting:
            return "Back to your normal connection in a moment."
        case .off:
            if model.servers.isEmpty { return "Add a server and you're one tap away." }
            return name.map { "Tap the button to appear in \($0)." } ?? "Pick a country below."
        }
    }

    @ViewBuilder
    private var timer: some View {
        if vpn.phase == .on, let since = vpn.connectedSince {
            Text(since, style: .timer)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
        } else {
            Text(" ")
                .font(.title3)
                .accessibilityHidden(true)
        }
    }

    private var locationButton: some View {
        Button {
            sheet = .countries
        } label: {
            HStack(spacing: 12) {
                CountryBadge(code: shownCountry?.code ?? Country.otherCode)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shownCountry?.name ?? "Pick a country")
                        .font(.headline)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Location, \(shownCountry?.name ?? "none"). Change country")
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Text("No servers yet")
                .font(.headline)
            Text("Hop connects through WireGuard servers. Add one and you're set.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Add Server") { sheet = .addServer }
                    .buttonStyle(.borderedProminent)
                Button("Where do I get one?") { sheet = .help }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var errorShown: Binding<Bool> {
        Binding(
            get: { vpn.errorMessage != nil },
            set: { if !$0 { vpn.errorMessage = nil } }
        )
    }
}
