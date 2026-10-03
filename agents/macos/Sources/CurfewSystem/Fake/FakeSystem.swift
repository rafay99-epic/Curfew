import Foundation

public struct FakeSystem: Sendable, Decodable {
    public struct User: Sendable, Decodable {
        public let name: String
        public let full: String
        public let admin: Bool
        public let state: SessionState
    }

    public let name: String?
    public let users: [User]
    public let apps: [String: [OpenApp]]?
    public let wake: String?

    public static func load(path: String) throws -> FakeSystem {
        try JSONDecoder().decode(FakeSystem.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
}

extension FakeSystem: UserDirectory, SessionMonitor, AppMonitor, HostInfo {
    public func humanUsers() -> [SystemUser] {
        users.enumerated().map { index, user in
            SystemUser(name: user.name, full: user.full, admin: user.admin, uid: uid_t(1000 + index))
        }
    }

    public func sessionStates() -> [String: SessionState] {
        Dictionary(users.map { ($0.name, $0.state) }, uniquingKeysWith: max)
    }

    public func openApps(of user: SystemUser) -> [OpenApp] {
        apps?[user.name] ?? []
    }

    public func hostName() -> String {
        name ?? MacHost().hostName()
    }

    public func osName() -> String {
        MacHost().osName()
    }

    public func wakeAddress() -> String? {
        wake
    }
}
