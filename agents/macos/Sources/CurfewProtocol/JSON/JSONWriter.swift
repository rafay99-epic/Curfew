extension JSONValue {
    public var text: String {
        var out: [UInt8] = []
        out.reserveCapacity(128)
        write(into: &out)
        return String(decoding: out, as: UTF8.self)
    }

    public var bytes: [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(128)
        write(into: &out)
        return out
    }

    private func write(into out: inout [UInt8]) {
        switch self {
        case .null: out.append(contentsOf: "null".utf8)
        case .bool(let flag): out.append(contentsOf: (flag ? "true" : "false").utf8)
        case .int(let number): out.append(contentsOf: String(number).utf8)
        case .double(let number): out.append(contentsOf: Self.format(number).utf8)
        case .string(let text): Self.quote(text, into: &out)
        case .array(let items):
            out.append(UInt8(ascii: "["))
            for (index, item) in items.enumerated() {
                if index > 0 { out.append(contentsOf: ", ".utf8) }
                item.write(into: &out)
            }
            out.append(UInt8(ascii: "]"))
        case .object(let members):
            out.append(UInt8(ascii: "{"))
            for (index, member) in members.enumerated() {
                if index > 0 { out.append(contentsOf: ", ".utf8) }
                Self.quote(member.key, into: &out)
                out.append(contentsOf: ": ".utf8)
                member.value.write(into: &out)
            }
            out.append(UInt8(ascii: "}"))
        }
    }

    private static func format(_ number: Double) -> String {
        if number.isNaN { return "NaN" }
        if number.isInfinite { return number > 0 ? "Infinity" : "-Infinity" }
        return String(number)
    }

    private static let hexDigits = Array("0123456789abcdef".utf8)

    private static func quote(_ text: String, into out: inout [UInt8]) {
        out.append(UInt8(ascii: "\""))
        for unit in text.utf16 {
            switch unit {
            case 0x22: out.append(contentsOf: "\\\"".utf8)
            case 0x5c: out.append(contentsOf: "\\\\".utf8)
            case 0x0a: out.append(contentsOf: "\\n".utf8)
            case 0x0d: out.append(contentsOf: "\\r".utf8)
            case 0x09: out.append(contentsOf: "\\t".utf8)
            case 0x08: out.append(contentsOf: "\\b".utf8)
            case 0x0c: out.append(contentsOf: "\\f".utf8)
            case 0x20...0x7e, 0x7f: out.append(UInt8(unit))
            default:
                out.append(contentsOf: "\\u".utf8)
                for shift in stride(from: 12, through: 0, by: -4) {
                    out.append(hexDigits[Int((unit >> UInt16(shift)) & 0xf)])
                }
            }
        }
        out.append(UInt8(ascii: "\""))
    }
}
