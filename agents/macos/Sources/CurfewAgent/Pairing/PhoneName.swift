import CurfewProtocol

enum PhoneName {
    static let fallback = "Phone"
    private static let allowedPunctuation: Set<Unicode.Scalar> = [" ", ".", "'", "(", ")", "+", "-", "_"]

    static func requested(in payload: String) -> String? {
        guard let json = JSONValue(parsing: payload), json.isObject else { return nil }
        switch json["name"] {
        case nil: return ""
        case .string(let text)?: return text
        case .int(let number)?: return String(number)
        case .bool(let flag)?: return flag ? "True" : "False"
        case .null?: return "None"
        default: return ""
        }
    }

    static func sanitized(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { isWordCharacter($0) || allowedPunctuation.contains($0) }
        let trimmed = String(String.UnicodeScalarView(kept)).trimmingSpaces
        let limited = String(String.UnicodeScalarView(trimmed.unicodeScalars.prefix(Limits.maxPhoneNameLength)))
        return limited.isEmpty ? fallback : limited
    }

    static func unique(_ name: String, taken: Set<String>) -> String {
        var candidate = name
        var number = 2
        while taken.contains(candidate) {
            candidate = "\(name) \(number)"
            number += 1
        }
        return candidate
    }

    private static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }
}

private extension String {
    var trimmingSpaces: String {
        let scalars = unicodeScalars
        guard let first = scalars.firstIndex(where: { $0 != " " }),
              let last = scalars.lastIndex(where: { $0 != " " })
        else { return "" }
        return String(scalars[first...last])
    }
}
