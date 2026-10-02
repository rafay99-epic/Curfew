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
        } actions: {
            actions
        }
    }

    @ViewBuilder private var actions: some View {
        switch model.stage {
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
