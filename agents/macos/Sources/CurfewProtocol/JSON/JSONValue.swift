public struct JSONMember: Sendable, Equatable {
    public let key: String
    public let value: JSONValue

    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
}

public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([JSONMember])

    public subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.last { $0.key == key }?.value
    }

    public var string: String? {
        if case .string(let text) = self { text } else { nil }
    }

    public var integer: Int? {
        if case .int(let number) = self { number } else { nil }
    }

    public var isObject: Bool {
        if case .object = self { true } else { false }
    }

    public var truthy: Bool {
        switch self {
        case .null: false
        case .bool(let flag): flag
        case .int(let number): number != 0
        case .double(let number): number != 0
        case .string(let text): !text.isEmpty
        case .array(let items): !items.isEmpty
        case .object(let members): !members.isEmpty
        }
    }
}

extension JSONValue: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(elements.map { JSONMember($0.0, $0.1) })
    }
}
