extension JSONValue {
    public init?(parsing text: String) {
        var parser = JSONParser(Array(text.utf8))
        guard let value = parser.document() else { return nil }
        self = value
    }

    public init?<Bytes: Collection>(parsing bytes: Bytes) where Bytes.Element == UInt8 {
        guard let text = StrictDecoding.decode(bytes, as: UTF8.self) else { return nil }
        self.init(parsing: text)
    }
}

private struct JSONParser {
    private let input: [UInt8]
    private var index = 0
    private var depth = 0
    private static let maxDepth = 512

    init(_ input: [UInt8]) {
        self.input = input
    }

    mutating func document() -> JSONValue? {
        guard let value = value() else { return nil }
        skipSpace()
        guard index == input.count else { return nil }
        return value
    }

    private var current: UInt8? {
        index < input.count ? input[index] : nil
    }

    private mutating func skipSpace() {
        while let char = current, char == 0x20 || char == 0x09 || char == 0x0a || char == 0x0d {
            index += 1
        }
    }

    private mutating func literal(_ word: String, _ value: JSONValue) -> JSONValue? {
        let bytes = Array(word.utf8)
        guard index + bytes.count <= input.count, Array(input[index..<index + bytes.count]) == bytes else { return nil }
        index += bytes.count
        return value
    }

    private mutating func value() -> JSONValue? {
        skipSpace()
        switch current {
        case UInt8(ascii: "{"): return nested { $0.object() }
        case UInt8(ascii: "["): return nested { $0.array() }
        case UInt8(ascii: "\""): return string().map(JSONValue.string)
        case UInt8(ascii: "t"): return literal("true", .bool(true))
        case UInt8(ascii: "f"): return literal("false", .bool(false))
        case UInt8(ascii: "n"): return literal("null", .null)
        case .some: return number()
        case nil: return nil
        }
    }

    private mutating func nested(_ body: (inout JSONParser) -> JSONValue?) -> JSONValue? {
        guard depth < Self.maxDepth else { return nil }
        depth += 1
        defer { depth -= 1 }
        return body(&self)
    }

    private mutating func object() -> JSONValue? {
        index += 1
        var members: [JSONMember] = []
        skipSpace()
        if current == UInt8(ascii: "}") {
            index += 1
            return .object(members)
        }
        while true {
            skipSpace()
            guard current == UInt8(ascii: "\""), let key = string() else { return nil }
            skipSpace()
            guard current == UInt8(ascii: ":") else { return nil }
            index += 1
            guard let item = value() else { return nil }
            members.append(JSONMember(key, item))
            skipSpace()
            switch current {
            case UInt8(ascii: ","): index += 1
            case UInt8(ascii: "}"):
                index += 1
                return .object(members)
            default: return nil
            }
        }
    }

    private mutating func array() -> JSONValue? {
        index += 1
        var items: [JSONValue] = []
        skipSpace()
        if current == UInt8(ascii: "]") {
            index += 1
            return .array(items)
        }
        while true {
            guard let item = value() else { return nil }
            items.append(item)
            skipSpace()
            switch current {
            case UInt8(ascii: ","): index += 1
            case UInt8(ascii: "]"):
                index += 1
                return .array(items)
            default: return nil
            }
        }
    }

    private mutating func string() -> String? {
        index += 1
        var units: [UInt16] = []
        var plain: [UInt8] = []
        func flush() {
            units.append(contentsOf: String(decoding: plain, as: UTF8.self).utf16)
            plain.removeAll(keepingCapacity: true)
        }
        while let char = current {
            index += 1
            switch char {
            case UInt8(ascii: "\""):
                flush()
                return StrictDecoding.decode(units, as: UTF16.self)
            case UInt8(ascii: "\\"):
                flush()
                guard let escaped = escape() else { return nil }
                units.append(escaped)
            case 0x00..<0x20:
                return nil
            default:
                plain.append(char)
            }
        }
        return nil
    }

    private mutating func escape() -> UInt16? {
        guard let char = current else { return nil }
        index += 1
        switch char {
        case UInt8(ascii: "\""): return 0x22
        case UInt8(ascii: "\\"): return 0x5c
        case UInt8(ascii: "/"): return 0x2f
        case UInt8(ascii: "b"): return 0x08
        case UInt8(ascii: "f"): return 0x0c
        case UInt8(ascii: "n"): return 0x0a
        case UInt8(ascii: "r"): return 0x0d
        case UInt8(ascii: "t"): return 0x09
        case UInt8(ascii: "u"):
            guard index + 4 <= input.count,
                  let code = UInt16(String(decoding: input[index..<index + 4], as: UTF8.self), radix: 16)
            else { return nil }
            index += 4
            return code
        default: return nil
        }
    }

    private mutating func number() -> JSONValue? {
        let start = index
        var integral = true
        if current == UInt8(ascii: "-") { index += 1 }
        guard let first = current, isDigit(first) else { return nil }
        if first == UInt8(ascii: "0") {
            index += 1
        } else {
            digits()
        }
        if current == UInt8(ascii: ".") {
            integral = false
            index += 1
            guard let next = current, isDigit(next) else { return nil }
            digits()
        }
        if current == UInt8(ascii: "e") || current == UInt8(ascii: "E") {
            integral = false
            index += 1
            if current == UInt8(ascii: "+") || current == UInt8(ascii: "-") { index += 1 }
            guard let next = current, isDigit(next) else { return nil }
            digits()
        }
        let text = String(decoding: input[start..<index], as: UTF8.self)
        if integral, let whole = Int(text) { return .int(whole) }
        return Double(text).map(JSONValue.double)
    }

    private mutating func digits() {
        while let char = current, isDigit(char) { index += 1 }
    }

    private func isDigit(_ char: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(char)
    }
}
