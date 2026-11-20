import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Bring in WireGuard configs from files or the clipboard, check them, then save.
struct AddServerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// When you came here by tapping a country, configs we can't place land there.
    var presetCountryCode: String? = nil

    @State private var drafts: [ServerDraft] = []
    @State private var typedText = ""
    @State private var showingImporter = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if drafts.isEmpty {
                    pickSource
                } else {
                    review
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(drafts.count > 1 ? "Add \(drafts.count)" : "Add") { save() }
                        .disabled(drafts.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.data, .plainText],
                allowsMultipleSelection: true
            ) { result in
                importFiles(result)
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var pickSource: some View {
        Section {
            Button {
                showingImporter = true
            } label: {
                Label("Choose .conf Files", systemImage: "doc.badge.plus")
            }
            Button {
                pasteFromClipboard()
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
            }
        } footer: {
            Text("Any WireGuard config works, from a VPN provider or your own server. You can pick several files at once.")
        }

        Section("Or paste it here") {
            TextEditor(text: $typedText)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 140)
            Button("Check Config") {
                read(typedText, fileName: nil)
            }
            .disabled(typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var review: some View {
        ForEach($drafts) { $draft in
            Section {
                TextField("Name", text: $draft.name)
                Picker("Country", selection: $draft.countryCode) {
                    ForEach(Country.all) { country in
                        Text(country.name).tag(country.code)
                    }
                }
            } header: {
                Text(draft.name)
            } footer: {
                if draft.countryCode == Country.otherCode {
                    Text("Hop couldn't tell where this server is. Pick its country so you can find it later.")
                }
            }
        }
        Section {
            Button("Start Over", role: .destructive) {
                drafts = []
                errorMessage = nil
            }
        }
    }

    // MARK: Reading

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        let text = UIPasteboard.general.string
        #else
        let text = NSPasteboard.general.string(forType: .string)
        #endif
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Your clipboard is empty. Copy a WireGuard config first."
            return
        }
        read(text, fileName: nil)
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var problems: [String] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    drafts.append(try makeDraft(text, fileName: url.lastPathComponent))
                } catch {
                    problems.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            errorMessage = problems.isEmpty ? nil : problems.joined(separator: "\n")
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func read(_ text: String, fileName: String?) {
        do {
            drafts.append(try makeDraft(text, fileName: fileName))
            typedText = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeDraft(_ text: String, fileName: String?) throws -> ServerDraft {
        var draft = try ServerLibrary.makeDraft(config: text, fileName: fileName)
        if draft.countryCode == Country.otherCode, let presetCountryCode {
            draft.countryCode = presetCountryCode
        }
        return draft
    }

    // MARK: Saving

    private func save() {
        var problems: [String] = []
        var saved: Set<UUID> = []
        for draft in drafts {
            do {
                try model.add(draft)
                saved.insert(draft.id)
            } catch {
                problems.append("\(draft.name): \(error.localizedDescription)")
            }
        }
        if problems.isEmpty {
            dismiss()
        } else {
            drafts.removeAll { saved.contains($0.id) }
            errorMessage = problems.joined(separator: "\n")
        }
    }
}
