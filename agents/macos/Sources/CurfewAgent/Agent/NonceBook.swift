import CurfewProtocol
import Foundation

actor NonceBook {
    private var store = NonceStore()

    func issue(to address: String) -> String {
        let nonce = Token.random(bytes: 16)
        store.issue(nonce, to: address, now: Self.now())
        return nonce
    }

    func consume(_ nonce: String) -> Bool {
        store.consume(nonce, now: Self.now())
    }

    private static func now() -> Double {
        ProcessInfo.processInfo.systemUptime
    }
}
