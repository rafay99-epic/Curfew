import CurfewProtocol
import Testing

@Suite struct JSONTests {
    @Test func writesLikePythonJSONDumps() {
        let value: JSONValue = ["ok": true, "timer": .null, "list": [1, "a"], "empty": [:], "name": "Mäc \"x\"\n😀"]
        #expect(value.text == #"{"ok": true, "timer": null, "list": [1, "a"], "empty": {}, "name": "M\u00e4c \"x\"\n\ud83d\ude00"}"#)
    }

    @Test func roundTripsUnicodeEscapes() throws {
        let parsed = try #require(JSONValue(parsing: #"{"name": "M\u00e4c \ud83d\ude00", "op": "status"}"#))
        #expect(parsed["name"] == .string("Mäc 😀"))
        #expect(parsed["op"]?.string == "status")
    }

    @Test func distinguishesNumbersAndBooleans() throws {
        let parsed = try #require(JSONValue(parsing: #"{"a": 15, "b": 15.0, "c": true, "d": -3, "e": 1e3}"#))
        #expect(parsed["a"] == .int(15))
        #expect(parsed["b"] == .double(15))
        #expect(parsed["c"] == .bool(true))
        #expect(parsed["d"]?.integer == -3)
        #expect(parsed["e"]?.integer == nil)
    }

    @Test func lastDuplicateKeyWins() throws {
        let parsed = try #require(JSONValue(parsing: #"{"op": "a", "op": "b"}"#))
        #expect(parsed["op"]?.string == "b")
    }

    @Test(arguments: [
        "", "{not json", "{\"a\": 1,}", "[1 2]", "\"\u{01}\"", "{\"a\": 01}", "\"\\ud800\"", "nul", "{} x",
    ])
    func rejectsMalformed(_ text: String) {
        #expect(JSONValue(parsing: text) == nil)
    }

    @Test func rejectsInvalidUTF8() {
        #expect(JSONValue(parsing: [UInt8]([0x22, 0xff, 0x22])) == nil)
    }

    @Test func limitsNesting() {
        #expect(JSONValue(parsing: String(repeating: "[", count: 600) + String(repeating: "]", count: 600)) == nil)
        #expect(JSONValue(parsing: String(repeating: "[", count: 100) + String(repeating: "]", count: 100)) != nil)
    }
}
