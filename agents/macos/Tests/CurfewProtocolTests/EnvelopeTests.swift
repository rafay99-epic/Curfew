import CurfewProtocol
import Testing

@Suite struct EnvelopeTests {
    @Test func codesUseTheAlphabet() {
        let code = PairingCode.generate()
        #expect(code.count == 16)
        #expect(code.allSatisfy(PairingCode.alphabet.contains))
        #expect(PairingCode.grouped("ABCD2345EFGH6789") == "ABCD-2345-EFGH-6789")
    }

    @Test func tokensFollowTheRules() {
        #expect(Token.isValid("abcdEFGH"))
        #expect(!Token.isValid("abcdefg"))
        #expect(!Token.isValid(String(repeating: "a", count: 65)))
        #expect(!Token.isValid("abcdefgh\n"))
        #expect(!Token.isValid("abcd-efgh"))
        #expect(Token.isMAC(String(repeating: "a", count: 64)))
        #expect(!Token.isMAC(String(repeating: "A", count: 64)))
        #expect(Token.random(bytes: 16).count == 32)
    }

    @Test func callRequestValidation() {
        let mac = String(repeating: "0", count: 64)
        let good: JSONValue = ["phone": "phone0001", "snonce": "snonce001", "cnonce": "cnonce001", "payload": "{}", "mac": .string(mac)]
        #expect(CallRequest(good) != nil)
        let numeric: JSONValue = ["phone": "phone0001", "snonce": "snonce001", "cnonce": "cnonce001", "payload": 1, "mac": .string(mac)]
        #expect(CallRequest(numeric) == nil)
        #expect(CallRequest(["phone": "x"]) == nil)
    }

    @Test func callSignatureRoundTrip() throws {
        let key = [UInt8](repeating: 7, count: 32)
        let payload = #"{"op": "status"}"#
        let mac = Signature.mac(key: key, "req", "phone0001", "snonce001", "cnonce001", payload)
        let request = try #require(CallRequest([
            "phone": "phone0001", "snonce": "snonce001", "cnonce": "cnonce001", "payload": .string(payload), "mac": .string(mac),
        ]))
        #expect(request.isSigned(by: key))
        #expect(!request.isSigned(by: [UInt8](repeating: 8, count: 32)))
        let answer = request.response(key: key, payload: "{}")
        #expect(answer["mac"]?.string == Signature.mac(key: key, "res", "phone0001", "snonce001", "cnonce001", "{}"))
    }

    @Test func opLookup() {
        #expect(OpLookup(.string("timer_set")) == .known(.timerSet))
        #expect(OpLookup(.string("run")) == .unknown)
        #expect(OpLookup(nil) == .unknown)
        #expect(OpLookup(.int(3)) == .unknown)
        #expect(OpLookup(.array([])) == .malformed)
    }
}
