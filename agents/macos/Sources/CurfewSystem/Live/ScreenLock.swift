import Darwin

public enum ScreenLock {
    static let framework = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"

    public static func lockAs(uid: uid_t) -> Bool {
        guard let entry = getpwuid(uid) else { return false }
        let gid = entry.pointee.pw_gid
        guard initgroups(entry.pointee.pw_name, Int32(bitPattern: gid)) == 0, setgid(gid) == 0, setuid(uid) == 0, getuid() == uid else {
            return false
        }
        return lockNow()
    }

    public static func lockNow() -> Bool {
        guard let handle = dlopen(framework, RTLD_LAZY), let symbol = dlsym(handle, "SACLockScreenImmediate") else { return false }
        typealias Lock = @convention(c) () -> Int32
        return unsafeBitCast(symbol, to: Lock.self)() == 0
    }
}
