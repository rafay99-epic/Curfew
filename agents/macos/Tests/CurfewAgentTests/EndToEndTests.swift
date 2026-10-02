@testable import CurfewAgent
import CurfewProtocol
import Darwin
import Foundation
import Testing

@Suite(.serialized) struct EndToEndTests {
    struct Client {
        let base: URL
        let session: URLSession

        init(port: UInt16) {
            base = URL(string: "http://127.0.0.1:\(port)")!
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.httpMaximumConnectionsPerHost = 1
            session = URLSession(configuration: configuration)
        }

        func send(_ method: String, _ path: String, _ body: [UInt8]? = nil) async throws -> (Int, JSONValue) {
            var request = URLRequest(url: base.appendingPathComponent(path))
            request.httpMethod = method
            request.httpBody = body.map { Data($0) }
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (status, try #require(JSONValue(parsing: [UInt8](data))))
        }

        func nonce() async throws -> String {
            try #require(try await send("GET", "/v1/hello").1["nonce"]?.string)
        }

        func call(_ phone: TestPhone, _ payload: JSONValue) async throws -> JSONValue {
            let snonce = try await nonce()
            let cnonce = Token.random(bytes: 16)
            let text = payload.text
            let envelope: JSONValue = [
                "phone": .string(phone.id), "snonce": .string(snonce), "cnonce": .string(cnonce), "payload": .string(text),
                "mac": .string(Signature.mac(key: phone.key, "req", phone.id, snonce, cnonce, text)),
            ]
            let (status, body) = try await send("POST", "/v1/call", envelope.bytes)
            try #require(status == 200)
            let answer = try #require(body["payload"]?.string)
            try #require(body["mac"]?.string == Signature.mac(key: phone.key, "res", phone.id, snonce, cnonce, answer))
            return try #require(JSONValue(parsing: answer))
        }
    }

    private func withServer(_ body: (Harness, UInt16) async throws -> Void) async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let agent = harness.agent
        let server = try HTTPServer(host: "127.0.0.1", port: 0) { request, address in
            await agent.respond(to: request, from: address)
        }
        let port = try await server.start()
        defer { server.stop() }
        await agent.start()
        try await body(harness, port)
    }

    @Test func pairCallAndForgetOverHTTP() async throws {
        try await withServer { harness, port in
            let client = Client(port: port)
            let (helloStatus, hello) = try await client.send("GET", "/v1/hello")
            #expect(helloStatus == 200 && hello["app"] == "curfew" && hello["proto"] == 1)
            let id = try await harness.store.read().id
            #expect(hello["id"]?.string == id)

            let code = PairingCode.generate()
            try await harness.offerPairing(code)
            let snonce = try await client.nonce()
            let cnonce = Token.random(bytes: 16)
            let payload = #"{"name": "Rafay's phone"}"#
            let request: JSONValue = [
                "snonce": .string(snonce), "cnonce": .string(cnonce), "payload": .string(payload),
                "mac": .string(Signature.mac(key: Array(code.utf8), "pair", snonce, cnonce, payload)),
            ]
            let (pairStatus, paired) = try await client.send("POST", "/v1/pair", request.bytes)
            try #require(pairStatus == 200)
            let phoneID = try #require(paired["phone"]?.string)
            let answer = try #require(paired["payload"]?.string)
            let key = Signature.deriveKey(code: code, snonce: snonce, cnonce: cnonce, phone: phoneID)
            #expect(paired["mac"]?.string == Signature.mac(key: key, "res", phoneID, snonce, cnonce, answer))
            let phone = TestPhone(id: phoneID, key: key)

            let status = try await client.call(phone, ["op": "status"])
            #expect(status["ok"] == true && status["id"]?.string == id && status["dry"] == true)
            #expect(try await client.call(phone, ["op": "timer_set", "seconds": 600, "warn": true]) == ["ok": true, "timer": ["remaining": 600, "warn": true]])
            #expect(try await client.call(phone, ["op": "status"])["timer"]?["warn"] == true)
            #expect(try await client.call(phone, ["op": "timer_cancel"]) == ["ok": true, "timer": .null])
            #expect(try await client.call(phone, ["op": "forget"]) == ["ok": true])
            let snonce2 = try await client.nonce()
            let gone: JSONValue = [
                "phone": .string(phoneID), "snonce": .string(snonce2), "cnonce": "cnonce1234", "payload": #"{"op": "status"}"#,
                "mac": .string(Signature.mac(key: key, "req", phoneID, snonce2, "cnonce1234", #"{"op": "status"}"#)),
            ]
            let (goneStatus, goneBody) = try await client.send("POST", "/v1/call", gone.bytes)
            #expect(goneStatus == 403 && goneBody == ["error": "unknown_phone"])
        }
    }

    @Test func malformedHTTPIsRefused() async throws {
        try await withServer { _, port in
            let client = Client(port: port)
            #expect(try await client.send("GET", "/etc/passwd").0 == 404)
            #expect(try await client.send("POST", "/v1/call", Array("{not json".utf8)).0 == 400)
            #expect(try await client.send("POST", "/v1/call", Array(repeating: UInt8(ascii: "x"), count: 20000)) == (400, ["error": "bad_request"]))
            #expect(try await client.send("POST", "/v1/call", Array("[1, 2]".utf8)).0 == 400)
            let reply = try RawSocket(port: port).exchange("GARBAGE\r\n\r\n")
            #expect(reply.hasPrefix("HTTP/1.1 400 "))
            let old = try RawSocket(port: port).exchange("GET /v1/hello HTTP/1.0\n\n")
            #expect(old.hasPrefix("HTTP/1.1 200 ") && old.contains("\"nonce\": "))
        }
    }

    @Test func atMostEightConnectionsPerAddress() async throws {
        try await withServer { _, port in
            let idle = try (0..<8).map { _ in try RawSocket(port: port) }
            try await Task.sleep(for: .milliseconds(200))
            let ninth = try RawSocket(port: port)
            #expect(ninth.readsEndOfStream())
            idle.forEach { $0.close() }
            try await Task.sleep(for: .milliseconds(200))
            #expect(try await Client(port: port).send("GET", "/v1/hello").0 == 200)
        }
    }
}

final class RawSocket {
    private let descriptor: Int32

    init(port: UInt16) throws {
        descriptor = socket(AF_INET, SOCK_STREAM, 0)
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard connected == 0 else { throw POSIXError(.ECONNREFUSED) }
    }

    func exchange(_ text: String) throws -> String {
        defer { close() }
        _ = text.withCString { send(descriptor, $0, strlen($0), 0) }
        var out: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = recv(descriptor, &buffer, buffer.count, 0)
            if count <= 0 { break }
            out += buffer.prefix(count)
        }
        return String(decoding: out, as: UTF8.self)
    }

    func readsEndOfStream() -> Bool {
        var byte: UInt8 = 0
        let count = recv(descriptor, &byte, 1, 0)
        close()
        return count <= 0 && !(count < 0 && errno == EAGAIN)
    }

    func close() {
        Darwin.close(descriptor)
    }
}
