@testable import CurfewApp
import CurfewControl
import CurfewProtocol
import Foundation
import os
import Testing

final class RecordingRunner: PrivilegedRunning {
    private let actions = OSAllocatedUnfairLock(initialState: [PrivilegedAction]())
    let outcome: PrivilegedError?

    init(outcome: PrivilegedError? = nil) {
        self.outcome = outcome
    }

    var ran: [PrivilegedAction] { actions.withLock { $0 } }

    @MainActor func run(_ action: PrivilegedAction) async throws(PrivilegedError) {
        actions.withLock { $0.append(action) }
        if let outcome { throw outcome }
    }
}

final class DryRunDaemon {
    let directory = "/tmp/cf-e2e-" + Token.random(bytes: 4)
    let port = UInt16.random(in: 40000...49000)
    private let process = Process()

    var socket: String { Layout.dryRunSocket(stateDirectory: directory) }

    static var binary: URL? {
        let candidate = Bundle(for: DryRunDaemon.self).bundleURL.deletingLastPathComponent().appending(path: "curfew")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    init() throws {
        let binary = try #require(Self.binary)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let fake = directory + "/fake.json"
        try Data(#"{"name": "MacBook Pro", "users": []}"#.utf8).write(to: URL(fileURLWithPath: fake))
        process.executableURL = binary
        process.arguments = ["serve", "--dry-run", "--bind", "127.0.0.1", "--port", String(port)]
        process.environment = ["CURFEW_STATE": directory, "CURFEW_FAKE": fake, "HOME": NSHomeDirectory()]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try process.run()
    }

    func waitUntilAnswering() async throws {
        for _ in 0..<100 {
            if (try? ControlSocket.exchange(socket, ControlRequest.status.json)) != nil { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("the dry-run daemon did not answer")
    }

    func stop() {
        process.terminate()
        process.waitUntilExit()
        try? FileManager.default.removeItem(atPath: directory)
    }

    func pairAsPhone(code: String, name: String) async throws -> Int {
        let base = try #require(URL(string: "http://127.0.0.1:\(port)"))
        let (helloData, _) = try await URLSession.shared.data(from: base.appending(path: "v1/hello"))
        let snonce = try #require(JSONValue(parsing: [UInt8](helloData))?["nonce"]?.string)
        let cnonce = Token.random(bytes: 16)
        let payload = (["name": .string(name)] as JSONValue).text
        let body: JSONValue = [
            "snonce": .string(snonce), "cnonce": .string(cnonce), "payload": .string(payload),
            "mac": .string(Signature.mac(key: Array(code.utf8), "pair", snonce, cnonce, payload)),
        ]
        var request = URLRequest(url: base.appending(path: "v1/pair"))
        request.httpMethod = "POST"
        request.httpBody = Data(body.bytes)
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}

@MainActor
@Suite(.serialized) struct EndToEndTests {
    func until(_ condition: () -> Bool) async throws {
        for _ in 0..<60 where !condition() {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func pairAndRemoveAPhoneAgainstTheDryRunDaemon() async throws {
        let daemon = try DryRunDaemon()
        defer { daemon.stop() }
        try await daemon.waitUntilAnswering()
        let runner = RecordingRunner()
        let model = CurfewModel(client: ControlClient(path: daemon.socket), runner: runner, isInstalled: { true }, computerName: "?")

        await model.refresh()
        #expect(model.stage == .running && model.computerName == "MacBook Pro" && model.phones.isEmpty)

        await model.startPairing()
        let offer = try #require(model.pairing)
        #expect(offer.address.hasSuffix(":\(daemon.port)") && offer.uri.hasSuffix("&c=\(offer.code)") && model.secondsLeft == 120)

        #expect(try await daemon.pairAsPhone(code: offer.code, name: "Rafay's Pixel") == 200)
        try await until { model.pairing == nil }
        #expect(model.notice == "Paired with Rafay's Pixel.")
        let phone = try #require(model.phones.first)
        #expect(model.phones.map(\.name) == ["Rafay's Pixel"])

        await model.unpair(phone)
        #expect(model.phones.isEmpty && model.notice == "Removed Rafay's Pixel.")
        #expect(runner.ran.isEmpty)
    }

    @Test func cancellingWithdrawsTheCode() async throws {
        let daemon = try DryRunDaemon()
        defer { daemon.stop() }
        try await daemon.waitUntilAnswering()
        let model = CurfewModel(client: ControlClient(path: daemon.socket), runner: RecordingRunner(), isInstalled: { true }, computerName: "?")
        await model.refresh()
        await model.startPairing()
        let offer = try #require(model.pairing)
        await model.cancelPairing()
        #expect(model.pairing == nil)
        #expect(try await daemon.pairAsPhone(code: offer.code, name: "Late") == 403)
    }

    @Test func reopeningTheAppResumesAnOpenPairing() async throws {
        let daemon = try DryRunDaemon()
        defer { daemon.stop() }
        try await daemon.waitUntilAnswering()
        let first = CurfewModel(client: ControlClient(path: daemon.socket), runner: RecordingRunner(), isInstalled: { true }, computerName: "?")
        await first.refresh()
        await first.startPairing()
        let second = CurfewModel(client: ControlClient(path: daemon.socket), runner: RecordingRunner(), isInstalled: { true }, computerName: "?")
        await second.refresh()
        #expect(second.pairing?.code == first.pairing?.code)
        await second.cancelPairing()
        await first.pollPairing()
        #expect(first.pairing == nil && first.notice == "The code was cancelled.")
    }

    @Test func stagesWithoutADaemon() async {
        let missing = "/tmp/cf-none-" + Token.random(bytes: 4) + ".sock"
        let fresh = CurfewModel(client: ControlClient(path: missing), runner: RecordingRunner(), isInstalled: { false }, computerName: "Mac")
        await fresh.refresh()
        #expect(fresh.stage == .setup)
        let stopped = CurfewModel(client: ControlClient(path: missing), runner: RecordingRunner(), isInstalled: { true }, computerName: "Mac")
        await stopped.refresh()
        #expect(stopped.stage == .stopped)
    }

    @Test func cancelledPasswordPromptChangesNothing() async {
        let runner = RecordingRunner(outcome: .cancelled)
        let model = CurfewModel(client: ControlClient(path: "/tmp/cf-none.sock"), runner: runner, isInstalled: { false }, computerName: "Mac")
        await model.setUp()
        #expect(runner.ran == [.install] && model.problem == nil && model.work == nil)
        let failing = RecordingRunner(outcome: .failed("launchd refused the service"))
        let broken = CurfewModel(client: ControlClient(path: "/tmp/cf-none.sock"), runner: failing, isInstalled: { true }, computerName: "Mac")
        await broken.startAgain()
        #expect(failing.ran == [.restart] && broken.problem == "launchd refused the service")
    }
}
