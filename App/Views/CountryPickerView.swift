import SwiftUI

struct CountryPickerView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.dismiss) private var dismiss
    @State private var addingFor: Country? = nil

    var body: some View {
        NavigationStack {
            List {
                if !model.countries.isEmpty {
                    Section("Your countries") {
                        ForEach(model.countries) { summary in
                            Button {
                                choose(summary.country.code)
                            } label: {
                                row(summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    ForEach(model.missingCountries) { country in
                        Button {
                            addingFor = country
                        } label: {
                            HStack(spacing: 12) {
                                CountryBadge(code: country.code, size: 34)
                                    .opacity(0.45)
                                Text(country.name)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Add server")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("More countries")
                } footer: {
                    Text("Add a WireGuard server for any of these and it moves up to your list.")
                }
            }
            .navigationTitle("Choose a Country")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $addingFor) { country in
                AddServerView(presetCountryCode: country.code)
                    .sheetChrome(model, vpn)
            }
        }
    }

    private func row(_ summary: CountrySummary) -> some View {
        HStack(spacing: 12) {
            CountryBadge(code: summary.country.code, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.country.name)
                Text(summary.serverCount == 1 ? "1 server" : "\(summary.serverCount) servers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if summary.country.code == model.selectedCountryCode {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Selected")
            }
        }
        .contentShape(Rectangle())
    }

    private func choose(_ code: String) {
        Task { await model.select(code, vpn: vpn) }
        dismiss()
    }
}
