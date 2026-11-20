import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var showingHelp = false
    @State private var editing: Server? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                if model.servers.isEmpty {
                    Section {
                        Text("No servers yet. Add a WireGuard config and you're ready to go.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(model.countries) { summary in
                    Section(summary.country.name) {
                        let list = model.servers(in: summary.country.code)
                        ForEach(list) { server in
                            Button {
                                editing = server
                            } label: {
                                ServerRow(server: server, isActive: isActive(server))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(server)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { delete(list[index]) }
                        }
                    }
                }

                Section {
                    Button {
                        showingHelp = true
                    } label: {
                        Label("Where do I get servers?", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddServerView().sheetChrome(model, vpn)
            }
            .sheet(isPresented: $showingHelp) {
                HelpView().sheetChrome(model, vpn)
            }
            .sheet(item: $editing) { server in
                EditServerView(server: server).sheetChrome(model, vpn)
            }
            .alert("Couldn't delete", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func isActive(_ server: Server) -> Bool {
        vpn.phase != .off && vpn.activeServerID == server.id
    }

    private func delete(_ server: Server) {
        if isActive(server) { vpn.disconnect() }
        do {
            try model.remove(server)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ServerRow: View {
    let server: Server
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            CountryBadge(code: server.countryCode, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                if let endpoint = server.endpoint {
                    Text(endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isActive {
                Text("Connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
    }
}

struct EditServerView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.dismiss) private var dismiss
    @State var server: Server
    @State private var errorMessage: String? = nil
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $server.name)
                    Picker("Country", selection: $server.countryCode) {
                        ForEach(Country.all) { country in
                            Text(country.name).tag(country.code)
                        }
                    }
                } footer: {
                    Text("Wrong country? Fix it here so the server shows up under the right place.")
                }

                Section("Details") {
                    LabeledContent("Server", value: server.endpoint ?? "Unknown")
                    LabeledContent("Added", value: server.addedAt.formatted(date: .abbreviated, time: .omitted))
                }

                Section {
                    Button("Delete Server", role: .destructive) {
                        confirmingDelete = true
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .confirmationDialog("Delete \(server.name)?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive) { delete() }
            } message: {
                Text("You can add it again later from the same config file.")
            }
        }
    }

    private func save() {
        do {
            try model.update(server)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        if vpn.phase != .off && vpn.activeServerID == server.id { vpn.disconnect() }
        do {
            try model.remove(server)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
