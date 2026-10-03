public enum WireError: String, Sendable, Error {
    case badRequest = "bad_request"
    case badNonce = "bad_nonce"
    case noPairing = "no_pairing"
    case badCode = "bad_code"
    case unknownPhone = "unknown_phone"
    case badMAC = "bad_mac"
    case notFound = "not_found"
    case unsupportedMethod = "unsupported_method"

    public var status: Int {
        switch self {
        case .badRequest: 400
        case .badNonce: 409
        case .noPairing, .badCode, .unknownPhone, .badMAC: 403
        case .notFound: 404
        case .unsupportedMethod: 501
        }
    }

    public var body: JSONValue {
        ["error": .string(rawValue)]
    }
}

public enum OpError: String, Sendable, Error {
    case badOp = "bad_op"
    case badUser = "bad_user"
    case badArgs = "bad_args"
    case badRequest = "bad_request"
    case notLoggedIn = "not_logged_in"
    case isAdmin = "is_admin"
    case noPassword = "no_password"
    case unsupported
    case failed
    case unpaired

    public var body: JSONValue {
        ["ok": false, "error": .string(rawValue)]
    }
}
