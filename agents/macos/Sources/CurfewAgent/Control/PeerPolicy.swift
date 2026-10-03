import CurfewSystem
import Darwin

public struct PeerPolicy: Sendable {
    public static let adminGroup: gid_t = 80

    public let dry: Bool
    public let isAdmin: @Sendable (uid_t) -> Bool

    public init(dry: Bool, isAdmin: @escaping @Sendable (uid_t) -> Bool) {
        self.dry = dry
        self.isAdmin = isAdmin
    }

    public static func system(dry: Bool) -> PeerPolicy {
        PeerPolicy(dry: dry, isAdmin: MacUserDirectory.isAdmin)
    }

    public func allows(uid: uid_t, gid: gid_t) -> Bool {
        dry || uid == 0 || gid == Self.adminGroup || isAdmin(uid)
    }
}
