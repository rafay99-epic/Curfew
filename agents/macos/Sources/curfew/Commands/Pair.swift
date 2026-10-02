import CurfewAgent
import CurfewProtocol
import Darwin
import Dispatch

enum Pair {
    static func run(_ settings: Settings) async throws -> Int32 {
        guard LocalNetwork.agentRunning(port: settings.port) else {
            print("The Curfew service is not running. Start it first" + (settings.dry ? " with: curfew serve --dry-run" : "."))
            return 1
        }
        guard let ip = LocalNetwork.lanAddress() else {
            print("This computer is not connected to a network. Connect to the home Wi-Fi first.")
            return 1
        }
        let store = settings.store
        let code = PairingCode.generate()
        let started = Wall.now()
        let id = try await store.update { state in
            state.offerPairing(code: code, now: started)
            return state.id
        }
        let address = settings.port == Limits.livePort ? ip : "\(ip):\(settings.port)"
        print("\nIn the Curfew app tap  Add computer  and scan this code:\n")
        print(QRTerminal.render("curfew://pair?a=\(ip):\(settings.port)&i=\(id)&c=\(code)") ?? "(the QR code could not be drawn)")
        print("\nOr type it in by hand:")
        print("    Address:  " + address)
        print("    Code:     " + PairingCode.grouped(code))
        print("\nThe code works once and expires in \(Int(PairingCode.lifetime) / 60) minutes. Waiting for the phone... (Ctrl+C to cancel)")
        let interrupt = cancelOnInterrupt(store: store, code: code)
        defer { interrupt.cancel() }
        while true {
            try await Task.sleep(for: .seconds(1))
            switch try await store.read().pairingProgress(code: code, since: started, now: Wall.now()) {
            case .pending:
                continue
            case .paired(let name):
                print("\nPaired with \"\(name)\". Done.")
                return 0
            case .cancelled:
                print("\nToo many wrong attempts; the code was cancelled. Run the command again.")
                return 1
            case .expired:
                print("\nThe code expired. Run the command again.")
                try await store.update { $0.withdrawPairing(code: code) }
                return 1
            }
        }
    }

    private static func cancelOnInterrupt(store: StateStore, code: String) -> any DispatchSourceSignal {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            Task {
                try? await store.update { $0.withdrawPairing(code: code) }
                print("\nCancelled.")
                exit(1)
            }
        }
        source.resume()
        return source
    }
}
