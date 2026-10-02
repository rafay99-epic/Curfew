public struct AgentState: Sendable, Equatable, Codable {
    public struct Phone: Sendable, Equatable, Codable {
        public var name: String
        public var key: String
        public var added: Int

        public init(name: String, key: String, added: Int) {
            self.name = name
            self.key = key
            self.added = added
        }
    }

    public struct RemovedPhone: Sendable, Equatable, Codable {
        public var key: String
        public var name: String
        public var when: Int

        public init(key: String, name: String, when: Int) {
            self.key = key
            self.name = name
            self.when = when
        }
    }

    public struct Pairing: Sendable, Equatable, Codable {
        public var code: String
        public var expires: Double
        public var fails: Int

        public init(code: String, expires: Double, fails: Int = 0) {
            self.code = code
            self.expires = expires
            self.fails = fails
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try container.decode(String.self, forKey: .code)
            expires = try container.decode(Double.self, forKey: .expires)
            fails = try container.decodeIfPresent(Int.self, forKey: .fails) ?? 0
        }
    }

    public struct Countdown: Sendable, Equatable, Codable {
        public var deadline: Double
        public var warn: Bool
        public var warned: Bool

        public init(deadline: Double, warn: Bool, warned: Bool) {
            self.deadline = deadline
            self.warn = warn
            self.warned = warned
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            deadline = try container.decode(Double.self, forKey: .deadline)
            warn = try container.decodeIfPresent(Bool.self, forKey: .warn) ?? false
            warned = try container.decodeIfPresent(Bool.self, forKey: .warned) ?? false
        }
    }

    public struct NetEntry: Sendable, Equatable, Codable {
        public var blocked: Bool?
        public var deadline: Double?
        public var warn: Bool?
        public var warned: Bool?
    }

    public struct LastPaired: Sendable, Equatable, Codable {
        public var name: String
        public var when: Double

        public init(name: String, when: Double) {
            self.name = name
            self.when = when
        }
    }

    public var id: String
    public var phones: [String: Phone]
    public var removed: [String: RemovedPhone]
    public var net: [String: NetEntry]
    public var pairing: Pairing?
    public var timer: Countdown?
    public var lastPaired: LastPaired?

    enum CodingKeys: String, CodingKey {
        case id, phones, removed, net, pairing, timer
        case lastPaired = "last_paired"
    }

    public init(id: String) {
        self.id = id
        phones = [:]
        removed = [:]
        net = [:]
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        phones = try container.decodeIfPresent([String: Phone].self, forKey: .phones) ?? [:]
        removed = try container.decodeIfPresent([String: RemovedPhone].self, forKey: .removed) ?? [:]
        net = try container.decodeIfPresent([String: NetEntry].self, forKey: .net) ?? [:]
        pairing = try container.decodeIfPresent(Pairing.self, forKey: .pairing)
        timer = try container.decodeIfPresent(Countdown.self, forKey: .timer)
        lastPaired = try container.decodeIfPresent(LastPaired.self, forKey: .lastPaired)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(phones, forKey: .phones)
        try container.encode(removed, forKey: .removed)
        try container.encode(net, forKey: .net)
        try container.encode(pairing, forKey: .pairing)
        try container.encode(timer, forKey: .timer)
        try container.encodeIfPresent(lastPaired, forKey: .lastPaired)
    }
}
