import CurfewProtocol
import Foundation
import Testing

struct Vectors: Decodable {
    struct Derive: Decodable {
        let code: String
        let snonce: String
        let cnonce: String
        let phone: String
        let key_hex: String
    }

    struct Signed: Decodable {
        let key_hex: String
        let parts: [String]
        let mac: String
    }

    struct Clean: Decodable {
        let `in`: String
        let out: String
    }

    let derive_key: [Derive]
    let mac: [Signed]
    let clean_code: [Clean]

    static func load(from file: String = #filePath) throws -> Vectors {
        var directory = URL(fileURLWithPath: file).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("protocol/vectors.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: candidate))
            }
            directory.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}

@Suite struct VectorTests {
    let vectors: Vectors

    init() throws {
        vectors = try Vectors.load()
    }

    @Test func keyDerivation() {
        #expect(!vectors.derive_key.isEmpty)
        for vector in vectors.derive_key {
            let key = Signature.deriveKey(code: vector.code, snonce: vector.snonce, cnonce: vector.cnonce, phone: vector.phone)
            #expect(Hex.encode(key) == vector.key_hex)
        }
    }

    @Test func signatures() throws {
        #expect(!vectors.mac.isEmpty)
        for vector in vectors.mac {
            let key = try #require(Hex.decode(vector.key_hex))
            #expect(Signature.mac(key: key, parts: vector.parts) == vector.mac)
        }
    }

    @Test func codeCleanup() {
        for vector in vectors.clean_code {
            #expect(PairingCode.clean(vector.in) == vector.out)
        }
    }
}
