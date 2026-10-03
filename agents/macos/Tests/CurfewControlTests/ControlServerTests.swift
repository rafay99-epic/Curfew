import CurfewAgent
import CurfewControl
import CurfewProtocol
import CurfewSystem
import Darwin
import Foundation
import Testing

struct ControlRig {
    let directory: String
    let store: StateStore
    let agent: Agent
    let service: ControlService
    let system: SystemServices
    var socket: String { directory + "/control.sock" }

    init() throws {
        directory = "/tmp/cf-" + Token.random(bytes: 4)
        store = StateStore(directory: directory)
        let log = Log(dry: true) { _ in }
        let fake = try JSONDecoder().decode(FakeSystem.self, from: Data(#"{"name": "MacBook Pro", "users": []}"#.utf8))
        agent = Agent(store: store, system: .fake(fake, log: log), log: log)
        system = .fake(fake, log: log)
        service = ControlService(store: store, system: system, port: 8787, dry: true, log: log) { "192.168.1.24" }
    }

    func serve(policy: PeerPolicy = PeerPolicy(dry: true) { _ in false }) throws -> ControlServer {
        _ = try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let service = self.service
        let server = try ControlServer(path: socket, access: .owner, policy: policy) { await service.respond(to: $0) }
        server.start()
        return server
    }

    func send(_ request: ControlRequest) throws -> JSONValue {
        try ControlSocket.exchange(socket, request.json)
    }

    func pairAsPhone(code: String, name: String) async throws -> HTTPResponse {
        let hello = await agent.respond(to: HTTPRequest(method: "GET", target: "/v1/hello", body: nil), from: "192.168.1.50")
        let snonce = try #require(hello.body["nonce"]?.string)
        let cnonce = Token.random(bytes: 16)
        let payload = (["name": .string(name)] as JSONValue).text
        let request: JSONValue = [
            "snonce": .string(snonce), "cnonce": .string(cnonce), "payload": .string(payload),
            "mac": .string(Signature.mac(key: Array(code.utf8), "pair", snonce, cnonce, payload)),
        ]
        return await agent.respond(to: HTTPRequest(method: "POST", target: "/v1/pair", body: request.bytes), from: "192.168.1.50")
    }

    func cleanUp() {
        try? FileManager.default.removeItem(atPath: directory)
    }
}

@Suite(.serialized) struct ControlServerTests {
    @Test func pairingStartedOverTheSocketCompletesOverTheLAN() async throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let server = try rig.serve()
        defer { server.stop() }

        let empty = try #require(ControlStatus(try rig.send(.status)))
        #expect(empty.name == "MacBook Pro" && empty.version == CurfewVersion.current && empty.phones.isEmpty && empty.pairing == nil)

        let offer = try #require(PairingOffer(try rig.send(.pairStart)))
        let id = try await rig.store.read().id
        #expect(offer.address == "192.168.1.24:8787" && offer.expiresIn == 120)
        #expect(offer.uri == "curfew://pair?a=192.168.1.24:8787&i=\(id)&c=\(offer.code)")
        #expect(PairingProgress(try rig.send(.pairStatus(code: offer.code))) == .pending(expiresIn: 120))
        #expect(ControlStatus(try rig.send(.status))?.pairing?.code == offer.code)

        #expect(try await rig.pairAsPhone(code: offer.code, name: "Rafay's Pixel").status == 200)
        #expect(PairingProgress(try rig.send(.pairStatus(code: offer.code))) == .paired(phone: "Rafay's Pixel"))
        let status = try #require(ControlStatus(try rig.send(.status)))
        let phone = try #require(status.phones.first)
        #expect(status.phones.count == 1 && phone.name == "Rafay's Pixel" && status.pairing == nil)

        #expect(try rig.send(.unpair(phone: phone.id)) == ["ok": true, "name": "Rafay's Pixel"])
        #expect(ControlError(reply: try rig.send(.unpair(phone: phone.id))) == .noPhone)
        #expect(try await rig.store.read().removed[phone.id] != nil)
    }

    @Test func settingsAreChangedOverTheSocket() async throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let server = try rig.serve()
        defer { server.stop() }
        let before = try #require(ControlStatus(try rig.send(.status)))
        #expect(before.settings == ControlSettings(login: false, loginReady: true, wake: true, awake: false))
        #expect(try rig.send(.set(.login, true)) == ["ok": true])
        #expect(try rig.send(.set(.awake, true)) == ["ok": true])
        #expect(try rig.send(.set(.wake, false)) == ["ok": true])
        let after = try #require(ControlStatus(try rig.send(.status)))
        #expect(after.settings == ControlSettings(login: true, loginReady: true, wake: false, awake: true))
        #expect(rig.system.login.isEnabled())
        #expect(try await rig.store.read().settings == AgentState.MacSettings(login: true, wake: false, awake: true))
    }

    @Test func cancelWithdrawsOnlyTheGivenCode() async throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let server = try rig.serve()
        defer { server.stop() }
        let offer = try #require(PairingOffer(try rig.send(.pairStart)))
        #expect(try rig.send(.pairCancel(code: "ZZZZZZZZZZZZZZZZ")) == ["ok": true])
        #expect(try await rig.store.read().pairing?.code == offer.code)
        #expect(try rig.send(.pairCancel(code: offer.code)) == ["ok": true])
        #expect(PairingProgress(try rig.send(.pairStatus(code: offer.code))) == .cancelled)
        #expect(try await rig.pairAsPhone(code: offer.code, name: "Late").body == ["error": "no_pairing"])
    }

    @Test func badLinesGetABadRequest() throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let server = try rig.serve()
        defer { server.stop() }
        #expect(ControlError(reply: try ControlSocket.exchange(rig.socket, ["cmd": "shutdown"])) == .badRequest)
        let raw = try ControlSocket.connect(rig.socket)
        defer { close(raw) }
        ControlSocket.writeLine(raw, "{not json")
        #expect(ControlSocket.readLine(raw, limit: 1000) == ControlError.badRequest.json.text)
    }

    @Test func refusedPeersAreTold() throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let server = try rig.serve(policy: PeerPolicy(dry: false) { _ in false })
        defer { server.stop() }
        #expect(throws: ControlSocketError.denied) { try rig.send(.status) }
    }

    @Test func socketIsPrivateAndStaleOnesAreReplaced() throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        let first = try rig.serve()
        let mode = try FileManager.default.attributesOfItem(atPath: rig.socket)[.posixPermissions] as? Int
        #expect(mode == 0o600)
        #expect(throws: ControlServerError.self) { try rig.serve() }
        first.stop()
        #expect(throws: ControlSocketError.unreachable) { try rig.send(.status) }
        let second = try rig.serve()
        defer { second.stop() }
        #expect(ControlStatus(try rig.send(.status)) != nil)
    }

    @Test func notASocketIsLeftAlone() throws {
        let rig = try ControlRig()
        defer { rig.cleanUp() }
        _ = try FileManager.default.createDirectory(atPath: rig.directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: rig.socket, contents: Data("keep".utf8))
        #expect(throws: ControlServerError.self) { try rig.serve() }
        #expect(FileManager.default.contents(atPath: rig.socket) == Data("keep".utf8))
    }
}
