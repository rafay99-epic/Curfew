import Foundation
import SwiftUI

struct MainView: View {
    let model: CurfewModel

    var body: some View {
        Page {
            SerifTitle(model.computerName)
            Lede(parts: lede)
            if let notice = model.notice {
                Text(notice)
                    .font(Theme.sans(15, .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 10)
            }
            if let problem = model.problem {
                Problem(text: problem)
            }
            if let offer = model.pairing {
                PairingView(offer: offer, secondsLeft: model.secondsLeft)
                    .padding(.top, 18)
            }
            if model.stage == .running, !model.phones.isEmpty {
                PhonesView(phones: model.phones) { phone in
                    Task { await model.unpair(phone) }
                }
                .padding(.top, 18)
            }
            if model.stage == .running, model.pairing == nil, let settings = model.settings {
                SettingsView(settings: settings, busy: model.changing) { model.toggle($0) }
                    .padding(.top, 26)
            }
        } actions: {
            actions
        }
        .alert("Log in from the phone?", isPresented: Bindable(model).confirmingLogin) {
            Button("Turn on") { Task { await model.set(.login, true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The login screen of this Mac gets a Curfew step. It fills in the password only after a paired phone approved that account, once, within two minutes. Remove Curfew to put the login screen back as it was.")
        }
    }

    @ViewBuilder private var actions: some View {
        switch model.stage {
        case .running where model.needsUpdate:
            SlabButton(title: model.work == .updating ? "Updating…" : "Update the background service", systemImage: "arrow.down.circle") {
                Task { await model.update() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.work != nil)
            about
        case .running where model.pairing != nil:
            GhostButton(title: "Cancel") {
                Task { await model.cancelPairing() }
            }
            .keyboardShortcut(.cancelAction)
            about
        case .running:
            SlabButton(title: "Pair a phone", systemImage: "qrcode") {
                Task { await model.startPairing() }
            }
            .keyboardShortcut(.defaultAction)
            about
        case .stopped:
            SlabButton(title: model.work == .starting ? "Starting…" : "Start it again", systemImage: "arrow.clockwise") {
                Task { await model.startAgain() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.work != nil)
            about
        case .denied:
            about
        case .checking, .setup:
            EmptyView()
        }
    }

    private var about: some View {
        GhostButton(title: "About") {
            model.screen = .about
        }
    }

    private var lede: [LedePart] {
        switch model.stage {
        case .checking: [.plain("Checking…")]
        case .setup: [.plain("Curfew is not set up yet.")]
        case .stopped: [.plain("Curfew is installed but not running.")]
        case .denied: [.plain("Only an administrator of this Mac can change Curfew.")]
        case .running where model.needsUpdate: [.plain("The background service is version \(model.serviceVersion ?? ""). This app is \(model.version). Update it to finish.")]
        case .running where model.phones.isEmpty: [.plain("Curfew is running. No phone is paired yet.")]
        case .running: [.plain("Curfew is running. "), .strong(Self.count(model.phones.count)), .plain(" can control this Mac.")]
        }
    }

    static func count(_ phones: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en")
        let number = phones <= 10 ? formatter.string(from: NSNumber(value: phones)) ?? String(phones) : String(phones)
        return number.prefix(1).uppercased() + number.dropFirst() + (phones == 1 ? " phone" : " phones")
    }
}
