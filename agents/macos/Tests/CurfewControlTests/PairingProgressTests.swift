import CurfewAgent
import CurfewControl
import CurfewProtocol
import Testing

@Suite struct PairingProgressTests {
    let code = "ABCDEFGHJKLMNPQR"

    func offered(at now: Double) -> AgentState {
        var state = AgentState(id: "0011223344556677")
        state.offerPairing(code: code, now: now)
        return state
    }

    @Test func pendingCountsDown() {
        let state = offered(at: 1000)
        #expect(state.pairingProgress(code: code, since: 1000, now: 1000) == .pending(expiresIn: 120))
        #expect(state.pairingProgress(code: code, since: 1000, now: 1077.5) == .pending(expiresIn: 43))
        #expect(state.pairingProgress(code: code, since: 1000, now: 1121) == .expired)
    }

    @Test func pairedAfterAPhoneUsedTheCode() {
        var state = offered(at: 1000)
        state.pairing = nil
        state.lastPaired = AgentState.LastPaired(name: "Rafay's Pixel", when: 1030)
        #expect(state.pairingProgress(code: code, since: 1000, now: 1031) == .paired(phone: "Rafay's Pixel"))
        #expect(state.pairingProgress(code: code, since: 1040, now: 1041) == .cancelled)
    }

    @Test func wrongAttemptsOrWithdrawalCancel() {
        var state = offered(at: 1000)
        state.withdrawPairing(code: "ZZZZZZZZZZZZZZZZ")
        #expect(state.pairing != nil)
        state.withdrawPairing(code: code)
        #expect(state.pairingProgress(code: code, since: 1000, now: 1010) == .cancelled)
        #expect(state.pairingProgress(code: code, since: 1000, now: 1200) == .expired)
    }

    @Test func aNewerCodeReplacesOurs() {
        var state = offered(at: 1000)
        state.offerPairing(code: "ZZZZZZZZZZZZZZZZ", now: 1005)
        #expect(state.pairingProgress(code: code, since: 1000, now: 1006) == .cancelled)
    }

    @Test func removingAPhoneKeepsItsKeyForTheGoodbye() {
        var state = AgentState(id: "0011223344556677")
        state.phones["p1"] = AgentState.Phone(name: "Work phone", key: "ab", added: 5)
        state.phones["p0"] = AgentState.Phone(name: "Rafay's Pixel", key: "cd", added: 1)
        #expect(state.orderedPhones.map(\.id) == ["p0", "p1"])
        #expect(state.removePhone("p1", now: 9)?.name == "Work phone")
        #expect(state.removed["p1"] == AgentState.RemovedPhone(key: "ab", name: "Work phone", when: 9))
        #expect(state.removePhone("p1", now: 10) == nil)
    }
}

@Suite struct PeerPolicyTests {
    @Test func onlyRootAndAdminsInLiveMode() {
        let policy = PeerPolicy(dry: false) { $0 == 501 }
        #expect(policy.allows(uid: 0, gid: 0))
        #expect(policy.allows(uid: 501, gid: 20))
        #expect(!policy.allows(uid: 502, gid: 20))
        #expect(policy.allows(uid: 503, gid: PeerPolicy.adminGroup))
    }

    @Test func dryRunSkipsTheAdminCheck() {
        let policy = PeerPolicy(dry: true) { _ in false }
        #expect(policy.allows(uid: 502, gid: 20))
    }
}
