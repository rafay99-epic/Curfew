@testable import CurfewSystem
import Foundation
import Testing

final class FakeAuthorizationDatabase: AuthorizationDatabase, @unchecked Sendable {
    private let lock = NSLock()
    private var rights: [String: [String: Any]]
    let loadsPlugin: Bool
    private(set) var checked: [String] = []

    init(loadsPlugin: Bool = true) {
        self.loadsPlugin = loadsPlugin
        rights = [
            LoginRights.console: [
                "class": "evaluate-mechanisms",
                "mechanisms": FakeAuthorizationDatabase.stock,
            ],
            LoginRights.screensaver: ["class": "rule", "rule": ["use-login-window-ui"], "k-of-n": 1],
        ]
    }

    static let stock = [
        "builtin:prelogin", "loginwindow:login", "builtin:auto-login,privileged", "builtin:authenticate,privileged",
        "builtin:login-success", "loginwindow:done",
    ]

    func read(_ right: String) -> [String: Any]? { lock.withLock { rights[right] } }

    func write(_ right: String, _ definition: [String: Any]) -> Bool {
        lock.withLock { rights[right] = definition }
        return true
    }

    func remove(_ right: String) -> Bool { lock.withLock { rights.removeValue(forKey: right) != nil } }

    func loads(_ right: String) -> Bool {
        lock.withLock { checked.append(right) }
        return loadsPlugin && read(right) != nil
    }

    var console: [String] { read(LoginRights.console)?["mechanisms"] as? [String] ?? [] }
    var screensaver: [String] { read(LoginRights.screensaver)?["rule"] as? [String] ?? [] }
}

@Suite struct LoginRightsTests {
    let bundle = NSTemporaryDirectory() + "cf-plugin-" + UUID().uuidString + "/CurfewLogin.bundle"

    func installBundle() throws {
        try FileManager.default.createDirectory(atPath: bundle + "/Contents/MacOS", withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: bundle + "/Contents/MacOS/CurfewLogin", contents: Data([0]))
    }

    func rights(_ database: FakeAuthorizationDatabase) -> LoginRights {
        LoginRights(log: Log(dry: false) { _ in }, database: database, bundlePath: bundle)
    }

    @Test func enablingWrapsTheBuiltInPasswordCheck() throws {
        try installBundle()
        let database = FakeAuthorizationDatabase()
        let login = rights(database)
        #expect(login.setEnabled(true))
        #expect(database.console == [
            "builtin:prelogin", "loginwindow:login", "builtin:auto-login,privileged",
            "CurfewLogin:login,privileged", "builtin:authenticate,privileged", "CurfewLogin:remember,privileged",
            "builtin:login-success", "loginwindow:done",
        ])
        #expect(database.screensaver == [LoginRights.unlockRight, "use-login-window-ui"])
        #expect(database.read(LoginRights.checkRight) == nil)
        #expect(database.checked == [LoginRights.checkRight])
        #expect(login.isEnabled())
        #expect(login.setEnabled(true))
        #expect(database.console.filter { $0.hasPrefix("CurfewLogin:") }.count == 2)
    }

    @Test func disablingPutsEverythingBack() throws {
        try installBundle()
        let database = FakeAuthorizationDatabase()
        let login = rights(database)
        #expect(login.setEnabled(true))
        #expect(login.setEnabled(false))
        #expect(database.console == FakeAuthorizationDatabase.stock)
        #expect(database.screensaver == ["use-login-window-ui"])
        #expect(database.read(LoginRights.unlockRight) == nil)
        #expect(!login.isEnabled())
    }

    @Test func aPluginMacOSWillNotLoadNeverReachesTheLoginScreen() throws {
        try installBundle()
        let database = FakeAuthorizationDatabase(loadsPlugin: false)
        let login = rights(database)
        #expect(!login.setEnabled(true))
        #expect(database.console == FakeAuthorizationDatabase.stock)
        #expect(database.screensaver == ["use-login-window-ui"])
        #expect(database.read(LoginRights.checkRight) == nil)
    }

    @Test func missingBundleIsNeverWiredIn() {
        let database = FakeAuthorizationDatabase()
        let login = rights(database)
        #expect(!login.isInstalled())
        #expect(!login.setEnabled(true))
        #expect(database.console == FakeAuthorizationDatabase.stock)
        #expect(database.checked.isEmpty)
    }

    @Test func syncRemovesALeftoverStepWhenTheBundleIsGone() throws {
        try installBundle()
        let database = FakeAuthorizationDatabase()
        #expect(rights(database).setEnabled(true))
        try FileManager.default.removeItem(atPath: bundle)
        #expect(!rights(database).sync(wanted: true))
        #expect(database.console == FakeAuthorizationDatabase.stock)
        #expect(rights(database).sync(wanted: false))
    }

    @Test func otherUnlockRulesAreKept() {
        #expect(LoginRights.withUnlock(["com.openai.x", "use-login-window-ui"]) == [LoginRights.unlockRight, "com.openai.x", "use-login-window-ui"])
        #expect(LoginRights.withUnlock("authenticate-session-owner-or-admin") == [LoginRights.unlockRight, "authenticate-session-owner-or-admin"])
        #expect(LoginRights.withUnlock([LoginRights.unlockRight, "use-login-window-ui"]) == [LoginRights.unlockRight, "use-login-window-ui"])
    }

    @Test func noAuthenticateStepMeansNoChange() {
        #expect(LoginRights.withPlugin(["loginwindow:login", "loginwindow:done"]) == ["loginwindow:login", "loginwindow:done"])
    }
}
