import SwiftUI

@main
struct HopApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var vpn = VPNController()

    var body: some Scene {
        #if os(macOS)
        Window("Hop", id: "main") {
            root
        }
        .defaultSize(width: 420, height: 660)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(vpn)
        } label: {
            Image(systemName: vpn.phase == .on ? "lock.shield.fill" : "lock.shield")
        }
        #else
        WindowGroup {
            root
        }
        #endif
    }

    private var root: some View {
        HomeView()
            .environmentObject(model)
            .environmentObject(vpn)
    }
}

extension View {
    /// Sheets get the shared objects passed in explicitly, plus a sensible
    /// size on the Mac where sheets otherwise shrink to fit.
    func sheetChrome(_ model: AppModel, _ vpn: VPNController) -> some View {
        #if os(macOS)
        return environmentObject(model)
            .environmentObject(vpn)
            .frame(minWidth: 440, idealWidth: 480, minHeight: 520, idealHeight: 620)
        #else
        return environmentObject(model)
            .environmentObject(vpn)
        #endif
    }
}
