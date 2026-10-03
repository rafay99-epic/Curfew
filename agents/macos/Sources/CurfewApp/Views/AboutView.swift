import Foundation
import SwiftUI

struct AboutView: View {
    static let author = URL(string: "https://rafay99.com")
    static let agent = URL(string: "https://github.com/sharjeelmazhar/Curfew")

    let model: CurfewModel
    @State private var licences = false
    @State private var confirmingRemoval = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Page {
            SerifTitle("Curfew")
            Credit(lead: "Made by ", name: "Abdul Rafay") { open(Self.author) }
            Credit(lead: "Built on the agent by ", name: "Sharjeel Mazhar") { open(Self.agent) }
            Lede(.plain("Everything stays on your home network. No account, no cloud."))
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(model.version) · com.rafay99.curfew")
                Text("MIT licence")
                Text("Fonts: Instrument Serif, Geist, Geist Mono")
                TextAction(licences ? "Hide font licences" : "Font licences (SIL OFL 1.1)") { licences.toggle() }
                    .underline()
                if model.stage == .running || model.stage == .stopped {
                    TextAction(model.work == .removing ? "Removing…" : "Remove Curfew from this Mac") { confirmingRemoval = true }
                        .underline()
                        .disabled(model.work != nil)
                        .padding(.top, 6)
                }
            }
            .font(Theme.mono(12))
            .foregroundStyle(Theme.dim)
            .padding(.top, 28)
            if let problem = model.problem {
                Problem(text: problem)
            }
            if licences {
                Text(Self.licenceText)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.dim)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }
        } actions: {
            GhostButton(title: "Back") { model.screen = .home }
                .keyboardShortcut(.cancelAction)
        }
        .alert("Remove Curfew from this Mac?", isPresented: $confirmingRemoval) {
            Button("Remove", role: .destructive) { Task { await model.removeFromMac() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Phones can no longer control this Mac. Pairings are kept in case you set it up again.")
        }
    }

    private func open(_ url: URL?) {
        if let url { openURL(url) }
    }

    static var licenceText: String {
        let files = (try? FileManager.default.contentsOfDirectory(at: AppResources.licences, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).map { url.deletingPathExtension().lastPathComponent + "\n\n" + $0 } }
            .joined(separator: "\n\n")
    }
}

private struct Credit: View {
    let lead: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(attributed)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.text)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var attributed: AttributedString {
        var link = AttributedString(name)
        link.underlineStyle = .single
        return AttributedString(lead) + link + AttributedString(".")
    }
}
