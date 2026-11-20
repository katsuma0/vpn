import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Hop is the remote. The server is the engine.")
                        .font(.title3.weight(.semibold))
                    Text("Every VPN needs a server in the country you want to show up in. Hop doesn't run servers of its own and doesn't collect anything about you. You bring a WireGuard config, Hop does the rest.")

                    step(1, "Grab a free config",
                         "Make a free Proton VPN account. On their website, open Downloads, choose WireGuard configuration, pick a free server in the country you want, and download the file.")
                    step(2, "Add it to Hop",
                         "Tap Add Server and choose the file. Hop reads the country from the file name. If it guesses wrong, you can fix it.")
                    step(3, "Tap the big button",
                         "That's it. Switch countries any time from the Location card.")

                    Text("Want more countries? Paid WireGuard providers hand out configs for dozens of them, or you can run your own server on a cheap cloud machine in any region you like.")
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Getting Servers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
