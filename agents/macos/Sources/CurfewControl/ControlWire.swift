import CurfewProtocol

public enum ControlRequest: Sendable, Equatable {
    case status
    case pairStart
    case pairStatus(code: String)
    case pairCancel(code: String)
    case unpair(phone: String)

    public var json: JSONValue {
        switch self {
        case .status: ["cmd": "status"]
        case .pairStart: ["cmd": "pair_start"]
        case .pairStatus(let code): ["cmd": "pair_status", "code": .string(code)]
        case .pairCancel(let code): ["cmd": "pair_cancel", "code": .string(code)]
        case .unpair(let phone): ["cmd": "unpair", "phone": .string(phone)]
        }
    }

    public init?(_ json: JSONValue) {
        switch (json["cmd"]?.string, json["code"]?.string, json["phone"]?.string) {
        case ("status"?, _, _): self = .status
        case ("pair_start"?, _, _): self = .pairStart
        case ("pair_status"?, let code?, _): self = .pairStatus(code: code)
        case ("pair_cancel"?, let code?, _): self = .pairCancel(code: code)
        case ("unpair"?, _, let phone?): self = .unpair(phone: phone)
        default: return nil
        }
    }
}

public enum ControlError: String, Sendable, Error, Equatable {
    case badRequest = "bad_request"
    case denied
    case noNetwork = "no_network"
    case noPhone = "no_phone"
    case failed

    public var json: JSONValue {
        ["ok": false, "error": .string(rawValue)]
    }

    public init?(reply: JSONValue) {
        guard reply["ok"] == false, let code = reply["error"]?.string else { return nil }
        self = ControlError(rawValue: code) ?? .failed
    }
}

public struct ControlPhone: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let pairedAt: Int

    public init(id: String, name: String, pairedAt: Int) {
        self.id = id
        self.name = name
        self.pairedAt = pairedAt
    }

    public var json: JSONValue {
        ["id": .string(id), "name": .string(name), "paired_at": .int(pairedAt)]
    }

    public init?(_ json: JSONValue) {
        guard let id = json["id"]?.string, let name = json["name"]?.string, let pairedAt = json["paired_at"]?.integer else { return nil }
        self.init(id: id, name: name, pairedAt: pairedAt)
    }
}

public struct PairingOffer: Sendable, Equatable {
    public let uri: String
    public let address: String
    public let code: String
    public let expiresIn: Int

    public init(address: String, agent: String, code: String, expiresIn: Int) {
        self.uri = "curfew://pair?a=\(address)&i=\(agent)&c=\(code)"
        self.address = address
        self.code = code
        self.expiresIn = expiresIn
    }

    public var codeLines: [String] {
        [PairingCode.grouped(String(code.prefix(8))), PairingCode.grouped(String(code.dropFirst(8)))]
    }

    public var members: [JSONMember] {
        [
            JSONMember("uri", .string(uri)),
            JSONMember("address", .string(address)),
            JSONMember("code", .string(code)),
            JSONMember("expires_in", .int(expiresIn)),
        ]
    }

    public init?(_ json: JSONValue) {
        guard let uri = json["uri"]?.string, let address = json["address"]?.string,
              let code = json["code"]?.string, let expiresIn = json["expires_in"]?.integer
        else { return nil }
        self.uri = uri
        self.address = address
        self.code = code
        self.expiresIn = expiresIn
    }
}

public struct ControlStatus: Sendable, Equatable {
    public let name: String
    public let version: String
    public let dry: Bool
    public let phones: [ControlPhone]
    public let pairing: PairingOffer?

    public init(name: String, version: String, dry: Bool, phones: [ControlPhone], pairing: PairingOffer?) {
        self.name = name
        self.version = version
        self.dry = dry
        self.phones = phones
        self.pairing = pairing
    }

    public var json: JSONValue {
        .object([
            JSONMember("ok", true),
            JSONMember("name", .string(name)),
            JSONMember("version", .string(version)),
            JSONMember("running", true),
            JSONMember("dry", .bool(dry)),
            JSONMember("phones", .array(phones.map(\.json))),
            JSONMember("pairing", pairing.map { .object($0.members) } ?? .null),
        ])
    }

    public init?(_ json: JSONValue) {
        guard json["ok"] == true, let name = json["name"]?.string, let version = json["version"]?.string,
              case .array(let list)? = json["phones"]
        else { return nil }
        let phones = list.compactMap(ControlPhone.init)
        guard phones.count == list.count else { return nil }
        self.init(
            name: name, version: version, dry: json["dry"] == true, phones: phones,
            pairing: json["pairing"].flatMap(PairingOffer.init)
        )
    }
}

public enum PairingProgress: Sendable, Equatable {
    case pending(expiresIn: Int)
    case paired(phone: String)
    case expired
    case cancelled

    public var json: JSONValue {
        switch self {
        case .pending(let seconds): ["ok": true, "state": "pending", "expires_in": .int(seconds)]
        case .paired(let phone): ["ok": true, "state": "paired", "phone": .string(phone)]
        case .expired: ["ok": true, "state": "expired"]
        case .cancelled: ["ok": true, "state": "cancelled"]
        }
    }

    public init?(_ json: JSONValue) {
        guard json["ok"] == true else { return nil }
        switch (json["state"]?.string, json["expires_in"]?.integer, json["phone"]?.string) {
        case ("pending"?, let seconds?, _): self = .pending(expiresIn: seconds)
        case ("paired"?, _, let phone?): self = .paired(phone: phone)
        case ("expired"?, _, _): self = .expired
        case ("cancelled"?, _, _): self = .cancelled
        default: return nil
        }
    }
}
