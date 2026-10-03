import CurfewProtocol
import Testing

@Suite struct NonceStoreTests {
    private func consume(_ store: inout NonceStore, _ nonce: String, _ now: Double, expect expected: Bool) {
        let used = store.consume(nonce, now: now)
        #expect(used == expected, "\(nonce) at \(now)")
    }

    @Test func singleUse() {
        var store = NonceStore()
        store.issue("n1", to: "a", now: 0)
        consume(&store, "n1", 1, expect: true)
        consume(&store, "n1", 1, expect: false)
        consume(&store, "never", 1, expect: false)
    }

    @Test func expiresAfterSixtySeconds() {
        var store = NonceStore()
        store.issue("n1", to: "a", now: 0)
        store.issue("n2", to: "a", now: 0)
        consume(&store, "n1", 60, expect: true)
        consume(&store, "n2", 60.5, expect: false)
    }

    @Test func expiredNoncesArePurgedOnIssue() {
        var store = NonceStore()
        store.issue("old", to: "a", now: 0)
        store.issue("new", to: "b", now: 61)
        #expect(store.count == 1)
    }

    @Test func atMost32UnusedPerAddressOldestDropped() {
        var store = NonceStore()
        store.issue("mine", to: "phone", now: 0)
        for index in 0..<100 {
            store.issue("flood\(index)", to: "attacker", now: 1)
        }
        #expect(store.count == 33)
        consume(&store, "flood0", 2, expect: false)
        consume(&store, "flood67", 2, expect: false)
        consume(&store, "flood68", 2, expect: true)
        consume(&store, "flood99", 2, expect: true)
        consume(&store, "mine", 2, expect: true)
    }

    @Test func globalCapacityDropsOldest() {
        var store = NonceStore()
        for index in 0..<(Limits.nonceCapacity + 10) {
            store.issue("n\(index)", to: "a\(index)", now: 0)
        }
        #expect(store.count == Limits.nonceCapacity)
        consume(&store, "n9", 0, expect: false)
        consume(&store, "n10", 0, expect: true)
    }
}
