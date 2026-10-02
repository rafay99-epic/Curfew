@testable import CurfewAgent
import CurfewProtocol
import Foundation
import Testing

@Suite struct OpDispatchTests {
    @Test func statusMatchesThePythonShape() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        let status = try await harness.call(phone, ["op": "status"])
        let id = try await harness.store.read().id
        let os = status["os"]?.string ?? ""
        #expect(status.text == """
            {"ok": true, "id": "\(id)", "name": "kids-laptop", "os": "\(os)", "users": [\
            {"name": "dad", "full": "Dad", "admin": true, "state": "none", "net": "on"}, \
            {"name": "classes", "full": "Ali (classes)", "admin": false, "state": "locked", "net": "on"}, \
            {"name": "gaming", "full": "Ali (gaming)", "admin": false, "state": "active", "net": "on"}], \
            "timer": null, "caps": ["seconds"], "dry": true}
            """)
    }

    @Test func appsByUser() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        let apps = try await harness.call(phone, ["op": "apps", "user": "gaming"])
        #expect(apps == ["ok": true, "apps": [["name": "Minecraft", "detail": "java -jar x.jar", "age": 340, "terminal": true]]])
        #expect(try await harness.call(phone, ["op": "apps", "user": "classes"]) == ["ok": true, "apps": []])
        #expect(try await harness.call(phone, ["op": "apps", "user": "root"]) == OpError.badUser.body)
        #expect(try await harness.call(phone, ["op": "apps"]) == OpError.badUser.body)
    }

    @Test func unknownMalformedAndUnsupportedOps() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "run", "cmd": "id"]) == OpError.badOp.body)
        #expect(try await harness.call(phone, ["cmd": "id"]) == OpError.badOp.body)
        #expect(try await harness.call(phone, ["op": ["status"]]) == OpError.badRequest.body)
        #expect(try await harness.call(phone, [1, 2]) == OpError.badRequest.body)
        for op in ["lock", "logout", "login", "net_set", "net_clear"] {
            #expect(try await harness.call(phone, ["op": .string(op), "user": "gaming"]) == OpError.unsupported.body)
        }
    }

    static let timerCases: [(JSONValue, Int?)] = [
        (["op": "timer_set", "seconds": 5], nil),
        (["op": "timer_set", "seconds": 10], 10),
        (["op": "timer_set", "seconds": 86400], 86400),
        (["op": "timer_set", "seconds": 86401], nil),
        (["op": "timer_set", "seconds": true], nil),
        (["op": "timer_set", "seconds": .double(30)], nil),
        (["op": "timer_set", "seconds": "30"], nil),
        (["op": "timer_set", "minutes": 0], nil),
        (["op": "timer_set", "minutes": 30], 1800),
        (["op": "timer_set", "minutes": 1441], nil),
        (["op": "timer_set", "seconds": .null, "minutes": 2], 120),
        (["op": "timer_set", "seconds": 30, "minutes": 2], 30),
        (["op": "timer_set", "minutes": .int(Int.max)], nil),
    ]

    @Test(arguments: timerCases)
    func timerArguments(_ payload: JSONValue, _ seconds: Int?) {
        #expect(Operations.countdown(payload) == seconds)
    }

    @Test func timerSetAndCancel() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "timer_set", "seconds": 5]) == OpError.badArgs.body)
        #expect(try await harness.call(phone, ["op": "timer_set", "minutes": 30, "warn": true]) == ["ok": true, "timer": ["remaining": 1800, "warn": true]])
        let timer = try await harness.store.read().timer
        #expect(timer?.warn == true && timer?.warned == false)
        #expect(harness.recorder.text.contains("would notify: This computer will shut down in 30 minutes."))
        let remaining = try await harness.call(phone, ["op": "status"])["timer"]?["remaining"]?.integer ?? -1
        #expect((1798...1800).contains(remaining))
        #expect(await harness.agent.scheduler.isArmed)
        #expect(try await harness.call(phone, ["op": "timer_set", "seconds": 45])["timer"] == ["remaining": 45, "warn": false])
        #expect(try await harness.store.read().timer?.warned == true)
        #expect(try await harness.call(phone, ["op": "timer_cancel"]) == ["ok": true, "timer": .null])
        #expect(try await harness.store.read().timer == nil)
        #expect(try await harness.call(phone, ["op": "status"])["timer"] == .null)
        #expect(await !harness.agent.scheduler.isArmed)
    }

    @Test func powerIsOnlyLoggedAfterTheReply() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        #expect(try await harness.call(phone, ["op": "reboot"]) == ["ok": true])
        #expect(!harness.recorder.text.contains("would restart"))
        try await Task.sleep(for: .milliseconds(1300))
        #expect(harness.recorder.text.contains("[dry-run] would restart the computer  (/sbin/shutdown -r now)"))
    }

    @Test func forgetAndUnpaired() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let a = try await harness.pairedPhone("A")
        let b = try await harness.pairedPhone("B")
        try await harness.store.update { state in
            if let phone = state.phones.removeValue(forKey: b.id) {
                state.removed[b.id] = AgentState.RemovedPhone(key: phone.key, name: phone.name, when: 0)
            }
        }
        #expect(try await harness.call(b, ["op": "poweroff"]) == OpError.unpaired.body)
        #expect(try await harness.call(a, ["op": "forget"]) == ["ok": true])
        let after = await harness.post("/v1/call", try await harness.envelope(a, ["op": "status"]))
        #expect(after.status == 403 && after.body == ["error": "unknown_phone"])
        #expect(try await harness.store.read().phones.isEmpty)
    }

    @Test func refusalsBeforeAuthentication() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let phone = try await harness.pairedPhone()
        let badKey = TestPhone(id: phone.id, key: [UInt8](repeating: 0, count: 32))
        #expect(await harness.post("/v1/call", try await harness.envelope(badKey, ["op": "status"])) == HTTPResponse(.badMAC))
        let envelope = try await harness.envelope(phone, ["op": "status"])
        #expect(await harness.post("/v1/call", envelope).status == 200)
        #expect(await harness.post("/v1/call", envelope) == HTTPResponse(.badNonce))
        #expect(await harness.post("/v1/call", ["phone": "x"]) == HTTPResponse(.badRequest))
        let raw = await harness.agent.respond(to: HTTPRequest(method: "POST", target: "/v1/call", body: Array("{not json".utf8)), from: "x")
        #expect(raw == HTTPResponse(.badRequest))
        let missing = await harness.agent.respond(to: HTTPRequest(method: "POST", target: "/v1/call", body: nil), from: "x")
        #expect(missing == HTTPResponse(.badRequest))
        let unknown = await harness.agent.respond(to: HTTPRequest(method: "POST", target: "/v1/other", body: nil), from: "x")
        #expect(unknown == HTTPResponse(.notFound))
        let path = await harness.agent.respond(to: HTTPRequest(method: "GET", target: "/v1/hello?x", body: nil), from: "x")
        #expect(path == HTTPResponse(.notFound))
    }

    @Test func humanDurations() {
        #expect(HumanDuration.text(30) == "30 seconds")
        #expect(HumanDuration.text(60) == "1 minute")
        #expect(HumanDuration.text(5400) == "1 hour 30 minutes")
        #expect(HumanDuration.text(7200) == "2 hours")
        #expect(HumanDuration.text(90) == "2 minutes")
        #expect(HumanDuration.text(150) == "2 minutes")
    }
}
