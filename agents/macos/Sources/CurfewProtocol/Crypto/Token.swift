public enum Token {
    public static func random(bytes count: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return Hex.encode((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }

    public static func isValid(_ text: String) -> Bool {
        let chars = text.utf8
        return (8...64).contains(chars.count) && chars.allSatisfy(isAlphanumeric)
    }

    public static func isMAC(_ text: String) -> Bool {
        let chars = text.utf8
        return chars.count == 64 && chars.allSatisfy { isDigit($0) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0) }
    }

    private static func isAlphanumeric(_ char: UInt8) -> Bool {
        isDigit(char)
            || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(char)
            || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(char)
    }

    private static func isDigit(_ char: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(char)
    }
}
