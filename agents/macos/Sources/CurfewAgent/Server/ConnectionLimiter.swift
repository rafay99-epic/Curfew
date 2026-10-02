import CurfewProtocol
import os

final class ConnectionLimiter: Sendable {
    private let open = OSAllocatedUnfairLock(initialState: [String: Int]())
    private let limit: Int

    init(limit: Int = Limits.connectionsPerAddress) {
        self.limit = limit
    }

    func acquire(_ address: String) -> Bool {
        open.withLock { counts in
            let current = counts[address, default: 0]
            guard current < limit else { return false }
            counts[address] = current + 1
            return true
        }
    }

    func release(_ address: String) {
        open.withLock { counts in
            let left = counts[address, default: 1] - 1
            counts[address] = left > 0 ? left : nil
        }
    }
}
