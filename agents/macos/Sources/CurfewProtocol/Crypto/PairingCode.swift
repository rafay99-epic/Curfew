public enum PairingCode {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static let length = 16
    public static let lifetime: Double = 120
    public static let maxFailures = 5

    public static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    public static func generate<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        String((0..<length).map { _ in alphabet[Int.random(in: alphabet.indices, using: &generator)] })
    }

    public static func clean(_ text: String) -> String {
        String(text.uppercased().unicodeScalars.filter { $0.isASCII && ($0.properties.isUppercase || ("0"..."9").contains($0)) })
    }

    public static func grouped(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4)
            .map { String(code.dropFirst($0).prefix(4)) }
            .joined(separator: "-")
    }
}
