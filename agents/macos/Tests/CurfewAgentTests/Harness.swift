@testable import CurfewAgent
import CurfewProtocol
import CurfewSystem
import Foundation
import os
import Testing

final class LogRecorder: Sendable {
    private let lines = OSAllocatedUnfairLock(initialState: [String]())

    var log: Log {
        Log(dry: true) { [lines] line in lines.withLock { $0.append(line) } }
    }

    var text: String {
        lines.withLock { $0.joined(separator: "\n") }
    }
}

struct TestPhone: Sendable {
    let id: String
    let key: [UInt8]
}

let kidsFake: FakeSystem = {
    let json = """
        {"name": "kids-laptop",
         "users": [
          {"name": "dad", "full": "Dad", "admin": true, "state": "none"},
          {"name": "classes", "full": "Ali (classes)", "admin": false, "state": "locked"},
          {"name": "gaming", "full": "Ali (gaming)", "admin": false, "state": "active"}],
         "apps": {"gaming": [{"name": "Minecraft", "detail": "java -jar x.jar", "age": 340, "terminal": true}]}}
        """
    do {
        return try JSONDecoder().decode(FakeSystem.self, from: Data(json.utf8))
    } catch {
        fatalError("bad fake: \(error)")
    }
}()

struct Harness: Sendable {
    let directory: String
    let recorder = LogRecorder()
    let store: StateStore
    let agent: Agent

    init() {
        directory = NSTemporaryDirectory() + "curfew-test-" + UUID().uuidString
        store = StateStore(directory: directory)
        let log = recorder.log
        agent = Agent(store: store, system: .fake(kidsFake, log: log), log: log)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(atPath: directory)
    }

    func hello(from address: String = "10.0.0.2") async throws -> String {
        let response = await agent.respond(to: HTTPRequest(method: "GET", target: "/v1/hello", body: nil), from: address)
        return try #require(response.body["nonce"]?.string)
    }

    func post(_ path: String, _ json: JSONValue) async -> HTTPResponse {
        await agent.respond(to: HTTPRequest(method: "POST", target: path, body: json.bytes), from: "10.0.0.2")
    }

    func offerPairing(_ code: String, expiresIn seconds: Double = 120) async throws {
        try await store.update { $0.pairing = AgentState.Pairing(code: code, expires: Wall.now() + seconds) }
    }

    func pair(code: String, name: String = "Dad's Galaxy", signWith signing: String? = nil) async throws -> (HTTPResponse, TestPhone?) {
        let snonce = try await hello()
        let cnonce = Token.random(bytes: 16)
        let payload = (["name": .string(name)] as JSONValue).text
        let mac = Signature.mac(key: Array((signing ?? code).utf8), "pair", snonce, cnonce, payload)
        let response = await post("/v1/pair", ["snonce": .string(snonce), "cnonce": .string(cnonce), "payload": .string(payload), "mac": .string(mac)])
        guard response.status == 200, let phone = response.body["phone"]?.string, let answer = response.body["payload"]?.string else {
            return (response, nil)
        }
        let key = Signature.deriveKey(code: code, snonce: snonce, cnonce: cnonce, phone: phone)
        #expect(response.body["mac"]?.string == Signature.mac(key: key, "res", phone, snonce, cnonce, answer))
        return (response, TestPhone(id: phone, key: key))
    }

    func envelope(_ phone: TestPhone, _ payload: JSONValue) async throws -> JSONValue {
        let snonce = try await hello()
        let cnonce = Token.random(bytes: 16)
        let text = payload.text
        return [
            "phone": .string(phone.id), "snonce": .string(snonce), "cnonce": .string(cnonce),
            "payload": .string(text), "mac": .string(Signature.mac(key: phone.key, "req", phone.id, snonce, cnonce, text)),
        ]
    }

    func call(_ phone: TestPhone, _ payload: JSONValue) async throws -> JSONValue {
        let envelope = try await envelope(phone, payload)
        let response = await post("/v1/call", envelope)
        try #require(response.status == 200, "status \(response.status) \(response.body.text)")
        let answer = try #require(response.body["payload"]?.string)
        let expected = Signature.mac(key: phone.key, "res", phone.id, envelope["snonce"]?.string ?? "", envelope["cnonce"]?.string ?? "", answer)
        #expect(response.body["mac"]?.string == expected)
        return try #require(JSONValue(parsing: answer))
    }

    func pairedPhone(_ name: String = "Dad's Galaxy") async throws -> TestPhone {
        try await offerPairing("ABCDEFGHJKLMNPQR")
        return try #require(try await pair(code: "ABCDEFGHJKLMNPQR", name: name).1)
    }
}
