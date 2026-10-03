@testable import CurfewAgent
import CurfewProtocol
import CurfewSystem
import Foundation
import Testing

@Suite struct AccountOpsTests {
    static func user(_ name: String, in status: JSONValue) -> JSONValue? {
        guard case .array(let users)? = status["users"] else { return nil }
        return users.first { $0["name"]?.string == name }
    }

    @Test func lockOnlyActsOnTheAccountOnScreen() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "lock", "user": "gaming"]) == ["ok": true])
        #expect(harness.recorder.text.contains("would lock the screen of gaming"))
        #expect(try await harness.call(phone, ["op": "lock", "user": "classes"]) == ["ok": true])
        #expect(!harness.recorder.text.contains("would lock the screen of classes"))
        #expect(try await harness.call(phone, ["op": "lock", "user": "dad"]) == OpError.notLoggedIn.body)
        #expect(try await harness.call(phone, ["op": "lock", "user": "root"]) == OpError.badUser.body)
    }

    @Test func logoutNeedsASession() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "logout", "user": "classes"]) == ["ok": true])
        #expect(harness.recorder.text.contains("would log out classes"))
        #expect(try await harness.call(phone, ["op": "logout", "user": "dad"]) == OpError.notLoggedIn.body)
    }

    @Test func loginIsOfferedOnlyWhenTurnedOn() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "status"])["caps"] == ["seconds", "net"])
        #expect(try await harness.call(phone, ["op": "login", "user": "classes"]) == OpError.unsupported.body)
        try await harness.store.update { $0.settings.login = true }
        #expect(try await harness.call(phone, ["op": "status"])["caps"] == ["seconds", "net", "login"])
        #expect(try await harness.call(phone, ["op": "login", "user": "classes"]) == ["ok": true, "how": "approved", "seconds": 120])
        #expect(try await harness.call(phone, ["op": "login", "user": "gaming"]) == ["ok": true, "how": "unlocked", "seconds": 120])
        let gate = try #require(harness.system.login as? DryRunLoginGate)
        let deadline = try #require(gate.approval(of: "classes"))
        #expect(abs(deadline - Wall.now() - 120) < 5)
        #expect(gate.approval(of: "gaming") == nil)
        #expect(try await harness.call(phone, ["op": "lock", "user": "classes"]) == ["ok": true])
        #expect(gate.approval(of: "classes") == nil)
    }

    @Test func internetOffNowThenBackOn() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "net_set", "user": "gaming", "seconds": 0]) == ["ok": true])
        #expect(harness.recorder.text.contains("would block the internet for: gaming"))
        #expect(Self.user("gaming", in: try await harness.call(phone, ["op": "status"]))?["net"] == "off")
        #expect(await harness.agent.scheduler.isArmed)
        #expect(try await harness.call(phone, ["op": "net_clear", "user": "gaming"]) == ["ok": true])
        #expect(harness.recorder.text.contains("would block the internet for: nobody"))
        #expect(try await harness.store.read().net.isEmpty)
        #expect(await !harness.agent.scheduler.isArmed)
    }

    @Test func internetRefusals() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "net_set", "user": "dad", "seconds": 0]) == OpError.isAdmin.body)
        #expect(try await harness.call(phone, ["op": "net_set", "user": "gaming", "seconds": 5]) == OpError.badArgs.body)
        #expect(try await harness.call(phone, ["op": "net_set", "user": "gaming"]) == OpError.badArgs.body)
        #expect(try await harness.call(phone, ["op": "net_set", "user": "nobody", "seconds": 0]) == OpError.badUser.body)
    }

    @Test func internetCountdownWarnsThenTurnsOff() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "net_set", "user": "gaming", "seconds": 10, "warn": true]) == ["ok": true])
        #expect(harness.recorder.text.contains("would notify gaming: The internet will turn off in 10 seconds."))
        let timer = Self.user("gaming", in: try await harness.call(phone, ["op": "status"]))?["net_timer"]
        #expect(timer?["warn"] == true)
        try await harness.store.update { $0.net["gaming"]?.deadline = Wall.now() + 0.5 }
        await harness.agent.scheduler.reschedule()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(try await harness.store.read().net["gaming"]?.blocked == true)
        #expect(harness.recorder.text.contains("would notify gaming: The internet has been turned off."))
        #expect(harness.recorder.text.contains("would block the internet for: gaming"))
    }

    @Test func statusCarriesTheWakeAddressOnlyWhenWakeIsOn() async throws {
        let harness = Harness(wake: "ac:07:75:20:78:14")
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "status"])["wake"] == "ac:07:75:20:78:14")
        try await harness.store.update { $0.settings.wake = false }
        #expect(try await harness.call(phone, ["op": "status"])["wake"] == nil)
    }

    @Test func startAppliesTheSavedSettings() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.store.update { $0.settings = AgentState.MacSettings(login: true, wake: true, awake: true) }
        await harness.agent.start()
        let log = harness.recorder.text
        #expect(log.contains("would turn login from the phone on"))
        #expect(log.contains("would turn wake for network access on"))
        #expect(log.contains("would keep the Mac awake on power"))
    }

    @Test func shutdownTimerIsMirroredAsAScheduledWake() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        _ = try await harness.call(phone, ["op": "timer_set", "minutes": 30])
        #expect(harness.recorder.text.contains("would ask the Mac to wake for the timer"))
        _ = try await harness.call(phone, ["op": "timer_cancel"])
        #expect(harness.recorder.text.contains("would cancel the scheduled wake"))
    }

    @Test func settingsSurviveAndDefaultSensibly() throws {
        let old = try JSONDecoder().decode(AgentState.self, from: Data(#"{"id": "x", "phones": {}}"#.utf8))
        #expect(old.settings == AgentState.MacSettings(login: false, wake: true, awake: false))
        var state = AgentState(id: "y")
        state.settings.login = true
        let again = try JSONDecoder().decode(AgentState.self, from: try JSONEncoder().encode(state))
        #expect(again.settings.login)
    }
}
