@testable import CurfewAgent
import CurfewProtocol
import Foundation
import Testing

@Suite struct PairingTests {
    @Test func noCodePendingIsRefused() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let (response, _) = try await harness.pair(code: "AAAABBBBCCCCDDDD")
        #expect(response.status == 403)
        #expect(response.body == ["error": "no_pairing"])
    }

    @Test func wrongCodeThenRightCodeThenReuse() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.offerPairing("AAAABBBBCCCCDDDD")
        let (wrong, _) = try await harness.pair(code: "AAAABBBBCCCCDDDD", signWith: "ZZZZZZZZZZZZZZZZ")
        #expect(wrong.body == ["error": "bad_code"])
        let (right, phone) = try await harness.pair(code: "AAAABBBBCCCCDDDD")
        #expect(phone != nil)
        let answer = try #require(right.body["payload"]?.string.flatMap { JSONValue(parsing: $0) })
        #expect(answer["phone_name"]?.string == "Dad's Galaxy")
        #expect(answer["name"]?.string == "kids-laptop")
        let state = try await harness.store.read()
        #expect(answer["id"]?.string == state.id)
        #expect(state.pairing == nil)
        #expect(state.lastPaired?.name == "Dad's Galaxy")
        let (reused, _) = try await harness.pair(code: "AAAABBBBCCCCDDDD")
        #expect(reused.body == ["error": "no_pairing"])
    }

    @Test func expiredCodeIsRefused() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.offerPairing("EEEEFFFFGGGGHHHH", expiresIn: -1)
        #expect(try await harness.pair(code: "EEEEFFFFGGGGHHHH").0.body == ["error": "no_pairing"])
    }

    @Test func cancelledAfterFiveWrongTries() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.offerPairing("JJJJKKKKLLLLMMMM")
        for attempt in 1...5 {
            #expect(try await harness.pair(code: "JJJJKKKKLLLLMMMM", signWith: "WRONGWRONGWRONGW").0.body == ["error": "bad_code"])
            let fails = try await harness.store.read().pairing?.fails
            #expect(fails == (attempt < 5 ? attempt : nil))
        }
        #expect(try await harness.pair(code: "JJJJKKKKLLLLMMMM").0.body == ["error": "no_pairing"])
    }

    @Test func namesAreCleanedAndMadeUnique() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        let first = try await harness.pairedPhone("Dad's Galaxy")
        let second = try await harness.pairedPhone("Dad's <Galaxy>")
        let third = try await harness.pairedPhone("<>{}")
        let phones = try await harness.store.read().phones
        #expect(phones[first.id]?.name == "Dad's Galaxy")
        #expect(phones[second.id]?.name == "Dad's Galaxy 2")
        #expect(phones[third.id]?.name == "Phone")
        #expect(first.key != second.key)
        #expect(PhoneName.sanitized("  Mäc 😀 phone  ") == "Mäc  phone")
        #expect(PhoneName.sanitized(String(repeating: "a", count: 50)).count == 40)
    }

    @Test func nonceIsSingleUseForPairing() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.offerPairing("AAAABBBBCCCCDDDD")
        let snonce = try await harness.hello()
        let payload = #"{"name": "x"}"#
        let body: JSONValue = [
            "snonce": .string(snonce), "cnonce": "cnonce1234", "payload": .string(payload),
            "mac": .string(Signature.mac(key: Array("ZZZZZZZZZZZZZZZZ".utf8), "pair", snonce, "cnonce1234", payload)),
        ]
        #expect(await harness.post("/v1/pair", body).body == ["error": "bad_code"])
        let replay = await harness.post("/v1/pair", body)
        #expect(replay.status == 409)
        #expect(replay.body == ["error": "bad_nonce"])
    }

    @Test func stateFileIsPrivate() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        _ = try await harness.store.read()
        let attributes = try FileManager.default.attributesOfItem(atPath: harness.directory + "/state.json")
        #expect((attributes[.posixPermissions] as? Int) == 0o600)
        let folder = try FileManager.default.attributesOfItem(atPath: harness.directory)
        #expect((folder[.posixPermissions] as? Int) == 0o700)
    }
}
