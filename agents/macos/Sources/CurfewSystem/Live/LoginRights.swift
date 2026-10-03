import CurfewLogin
import Foundation

public struct LoginRights: LoginGate {
    public static let console = "system.login.console"
    public static let screensaver = "system.login.screensaver"
    public static let unlockRight = "com.rafay99.curfew.unlock"
    public static let checkRight = "com.rafay99.curfew.check"
    public static let bundle = "/Library/Security/SecurityAgentPlugins/CurfewLogin.bundle"
    static let login = "CurfewLogin:login,privileged"
    static let remember = "CurfewLogin:remember,privileged"
    static let unlock = "CurfewLogin:unlock,privileged"
    static let directory = CURFEW_LOGIN_DIR

    private let log: Log
    private let database: any AuthorizationDatabase
    private let bundlePath: String

    public init(log: Log, database: any AuthorizationDatabase = SecurityAuthorizationDatabase(), bundlePath: String = Self.bundle) {
        self.log = log
        self.database = database
        self.bundlePath = bundlePath
    }

    public func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: bundlePath + "/Contents/MacOS/CurfewLogin")
    }

    public func isEnabled() -> Bool {
        mechanisms(database.read(Self.console)).contains(Self.login)
    }

    public func setEnabled(_ on: Bool) -> Bool {
        on ? enable() : disable()
    }

    public func sync(wanted: Bool) -> Bool {
        if wanted, enable() { return true }
        if isEnabled() || database.read(Self.unlockRight) != nil { _ = disable() }
        return !wanted
    }

    public func knowsPassword(of user: String) -> Bool {
        curfew_knows(Self.directory, user) == 1
    }

    public func approve(_ user: String, until deadline: Double) -> Bool {
        curfew_approve(Self.directory, user, deadline) == 1
    }

    public func revoke(_ user: String) {
        curfew_revoke(Self.directory, user)
    }

    private func enable() -> Bool {
        guard isInstalled() else {
            log("login: the login plugin is not installed")
            return false
        }
        guard database.write(Self.checkRight, Self.definition([Self.remember])) else {
            log("login: the check could not be set up")
            return false
        }
        let loads = database.loads(Self.checkRight)
        _ = database.remove(Self.checkRight)
        guard loads else {
            log("login: macOS did not load the login plugin, so the login screen is left as it was")
            return false
        }
        guard var console = database.read(Self.console), console["mechanisms"] is [String] else {
            log("login: the login rules could not be read")
            return false
        }
        let wanted = Self.withPlugin(mechanisms(console))
        if mechanisms(console) != wanted {
            console["mechanisms"] = wanted
            guard database.write(Self.console, console) else {
                log("login: the login rules could not be written")
                return false
            }
            log("login from the phone is on")
        }
        enableUnlock()
        return true
    }

    private func enableUnlock() {
        guard database.write(Self.unlockRight, Self.definition([Self.unlock])),
              var screensaver = database.read(Self.screensaver)
        else { return }
        let rules = Self.withUnlock(screensaver["rule"])
        guard (screensaver["rule"] as? [String]) != rules else { return }
        screensaver["class"] = "rule"
        screensaver["rule"] = rules
        screensaver["k-of-n"] = 1
        if !database.write(Self.screensaver, screensaver) { log("login: the screen unlock rule could not be written") }
    }

    private func disable() -> Bool {
        var ok = true
        if var console = database.read(Self.console), let list = console["mechanisms"] as? [String] {
            let cleaned = Self.withoutPlugin(list)
            if cleaned != list {
                console["mechanisms"] = cleaned
                ok = database.write(Self.console, console)
                log(ok ? "login from the phone is off" : "login: the login rules could not be written")
            }
        }
        if var screensaver = database.read(Self.screensaver), let rules = screensaver["rule"] as? [String], rules.contains(Self.unlockRight) {
            screensaver["rule"] = rules.filter { $0 != Self.unlockRight }
            ok = database.write(Self.screensaver, screensaver) && ok
        }
        if database.read(Self.unlockRight) != nil { _ = database.remove(Self.unlockRight) }
        return ok
    }

    private func mechanisms(_ rule: [String: Any]?) -> [String] {
        rule?["mechanisms"] as? [String] ?? []
    }

    static func definition(_ mechanisms: [String]) -> [String: Any] {
        ["class": "evaluate-mechanisms", "mechanisms": mechanisms, "shared": true, "tries": 1, "comment": "Curfew: log in from a paired phone."]
    }

    static func withoutPlugin(_ mechanisms: [String]) -> [String] {
        mechanisms.filter { !$0.hasPrefix("CurfewLogin:") }
    }

    static func withPlugin(_ mechanisms: [String]) -> [String] {
        var list = withoutPlugin(mechanisms)
        guard let authenticate = list.firstIndex(of: "builtin:authenticate,privileged") else { return list }
        list.insert(remember, at: authenticate + 1)
        list.insert(login, at: authenticate)
        return list
    }

    static func withUnlock(_ rule: Any?) -> [String] {
        let current = (rule as? [String]) ?? (rule as? String).map { [$0] } ?? ["use-login-window-ui"]
        return [unlockRight] + current.filter { $0 != unlockRight }
    }
}
