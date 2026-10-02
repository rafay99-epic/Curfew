import AppKit
import SwiftUI

struct FirstRunView: View {
    let model: CurfewModel

    var body: some View {
        Page {
            SerifTitle("Set up this Mac")
            Lede(
                .plain("Curfew runs quietly in the background so your phone can shut this Mac down, set timers, lock it and log you in. It asks for your password "),
                .strong("once"),
                .plain(".")
            )
            HairlineRow {
                Text("Background service").font(Theme.sans(14.5)).foregroundStyle(Theme.text)
            } trailing: {
                Text("about 3 MB, idle at 0%").font(Theme.mono(12.5)).foregroundStyle(Theme.dim)
            }
            .padding(.top, 20)
            if let problem = model.problem {
                Problem(text: problem)
            }
        } actions: {
            SlabButton(title: model.work == .settingUp ? "Setting up…" : "Set up", systemImage: "checkmark") {
                Task { await model.setUp() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.work != nil)
            GhostButton(title: "Not now") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut(.cancelAction)
            .disabled(model.work != nil)
        }
    }
}

struct Problem: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(12.5))
            .foregroundStyle(Theme.dim)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(.top, 14)
    }
}
