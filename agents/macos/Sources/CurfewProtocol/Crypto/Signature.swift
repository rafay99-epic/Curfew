import CryptoKit
import Foundation

public enum Signature {
    public static func mac(key: [UInt8], _ parts: String...) -> String {
        mac(key: key, parts: parts)
    }

    public static func mac(key: [UInt8], parts: [String]) -> String {
        Hex.encode(hmac(key: key, message: parts.joined(separator: "\n")))
    }

    public static func deriveKey(code: String, snonce: String, cnonce: String, phone: String) -> [UInt8] {
        hmac(key: Array(code.utf8), message: ["key", snonce, cnonce, phone].joined(separator: "\n"))
    }

    public static func matches(_ expected: String, _ given: String) -> Bool {
        let a = Array(expected.utf8)
        let b = Array(given.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices {
            difference |= a[index] ^ b[index]
        }
        return difference == 0
    }

    private static func hmac(key: [UInt8], message: String) -> [UInt8] {
        Array(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key)))
    }
}
