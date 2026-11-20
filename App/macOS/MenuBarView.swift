#if os(macOS)
import SwiftUI
import AppKit

/// The menu bar shield: connect, disconnect and switch countries without
/// opening the window.
struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)

        Button(vpn.phase == .off ? "Connect" : "Disconnect") {
            Task { await model.toggle(vpn) }
        }
        .disabled(vpn.phase == .off && model.selectedServer == nil)

        if !model.countries.isEmpty {
            Divider()
            ForEach(model.countries) { summary in
                Toggle(summary.country.name, isOn: Binding(
                    get: { model.selectedCountryCode == summary.country.code },
                    set: { isOn in
                        if isOn { Task { await model.select(summary.country.code, vpn: vpn) } }
                    }
                ))
            }
        }

        Divider()
        Button("Open Hop") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit Hop") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusLine: String {
        switch vpn.phase {
        case .off: return "Not connected"
        case .connecting: return "Connecting..."
        case .disconnecting: return "Disconnecting..."
        case .on:
            let name = model.server(id: vpn.activeServerID)?.country.name ?? "VPN"
            return "Connected to \(name)"
        }
    }
}
#endif
