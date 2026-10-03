public struct PairRequest: Sendable, Equatable {
    public let snonce: String
    public let cnonce: String
    public let payload: String
    public let mac: String

    public init?(_ json: JSONValue) {
        guard let payload = json["payload"]?.string,
              let snonce = json["snonce"]?.string, Token.isValid(snonce),
              let cnonce = json["cnonce"]?.string, Token.isValid(cnonce),
              let mac = json["mac"]?.string, Token.isMAC(mac)
        else { return nil }
        self.snonce = snonce
        self.cnonce = cnonce
        self.payload = payload
        self.mac = mac
    }

    public func isSigned(byCode code: String) -> Bool {
        Signature.matches(Signature.mac(key: Array(code.utf8), "pair", snonce, cnonce, payload), mac)
    }

    public func key(code: String, phone: String) -> [UInt8] {
        Signature.deriveKey(code: code, snonce: snonce, cnonce: cnonce, phone: phone)
    }

    public func response(phone: String, key: [UInt8], payload answer: String) -> JSONValue {
        [
            "phone": .string(phone),
            "payload": .string(answer),
            "mac": .string(Signature.mac(key: key, "res", phone, snonce, cnonce, answer)),
        ]
    }
}

public struct CallRequest: Sendable, Equatable {
    public let phone: String
    public let snonce: String
    public let cnonce: String
    public let payload: String
    public let mac: String

    public init?(_ json: JSONValue) {
        guard let payload = json["payload"]?.string,
              let phone = json["phone"]?.string, Token.isValid(phone),
              let snonce = json["snonce"]?.string, Token.isValid(snonce),
              let cnonce = json["cnonce"]?.string, Token.isValid(cnonce),
              let mac = json["mac"]?.string, Token.isMAC(mac)
        else { return nil }
        self.phone = phone
        self.snonce = snonce
        self.cnonce = cnonce
        self.payload = payload
        self.mac = mac
    }

    public func isSigned(by key: [UInt8]) -> Bool {
        Signature.matches(Signature.mac(key: key, "req", phone, snonce, cnonce, payload), mac)
    }

    public func response(key: [UInt8], payload answer: String) -> JSONValue {
        [
            "payload": .string(answer),
            "mac": .string(Signature.mac(key: key, "res", phone, snonce, cnonce, answer)),
        ]
    }
}
