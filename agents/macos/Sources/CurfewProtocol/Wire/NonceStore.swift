public struct NonceStore: Sendable {
    private struct Entry: Sendable {
        let nonce: String
        let address: String
        let expires: Double
    }

    private var entries: [Entry] = []

    public init() {}

    public var count: Int { entries.count }

    public mutating func issue(_ nonce: String, to address: String, now: Double) {
        entries.removeAll { $0.expires < now }
        var excess = entries.count { $0.address == address } - Limits.noncesPerAddress + 1
        if excess > 0 {
            entries.removeAll { entry in
                guard excess > 0, entry.address == address else { return false }
                excess -= 1
                return true
            }
        }
        if entries.count >= Limits.nonceCapacity {
            entries.removeFirst(entries.count - Limits.nonceCapacity + 1)
        }
        entries.append(Entry(nonce: nonce, address: address, expires: now + Limits.nonceLifetime))
    }

    public mutating func consume(_ nonce: String, now: Double) -> Bool {
        guard let index = entries.firstIndex(where: { $0.nonce == nonce }) else { return false }
        return entries.remove(at: index).expires >= now
    }
}
