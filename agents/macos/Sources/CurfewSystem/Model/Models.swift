import Darwin

public struct SystemUser: Sendable, Equatable {
    public let name: String
    public let full: String
    public let admin: Bool
    public let uid: uid_t

    public init(name: String, full: String, admin: Bool, uid: uid_t) {
        self.name = name
        self.full = full
        self.admin = admin
        self.uid = uid
    }
}

public enum SessionState: String, Sendable, Codable, Comparable {
    case none
    case loggedIn = "logged_in"
    case locked
    case active

    private var rank: Int {
        switch self {
        case .none: 0
        case .loggedIn: 1
        case .locked: 2
        case .active: 3
        }
    }

    public static func < (lhs: SessionState, rhs: SessionState) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct OpenApp: Sendable, Equatable, Codable {
    public let name: String
    public let detail: String
    public let age: Int
    public let terminal: Bool

    public init(name: String, detail: String, age: Int, terminal: Bool) {
        self.name = name
        self.detail = detail
        self.age = age
        self.terminal = terminal
    }
}

public enum PowerAction: String, Sendable {
    case poweroff
    case reboot
}
