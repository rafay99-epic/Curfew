import os

public struct DryRunNotifier: Notifier {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func notify(_ text: String, user: String?) {
        log("would notify" + (user.map { " \($0)" } ?? "") + ": \(text)")
    }
}

public struct DryRunSessionControl: SessionControl {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func lock(_ user: SystemUser) -> Bool {
        log("would lock the screen of \(user.name)")
        return true
    }

    public func logout(_ user: SystemUser) -> Bool {
        log("would log out \(user.name)")
        return true
    }
}

public struct DryRunFirewall: Firewall {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func apply(blocked users: [SystemUser]) -> Bool {
        log("would block the internet for: " + (users.map(\.name).joined(separator: ", ").nilIfEmpty ?? "nobody"))
        return true
    }
}

public final class DryRunLoginGate: LoginGate {
    private let log: Log
    private let state = OSAllocatedUnfairLock(initialState: (enabled: false, approved: [String: Double]()))

    public init(log: Log) {
        self.log = log
    }

    public func isInstalled() -> Bool { true }

    public func isEnabled() -> Bool { state.withLock { $0.enabled } }

    public func setEnabled(_ on: Bool) -> Bool {
        state.withLock { $0.enabled = on }
        log("would turn login from the phone \(on ? "on" : "off")")
        return true
    }

    public func sync(wanted: Bool) -> Bool {
        setEnabled(wanted)
    }

    public func knowsPassword(of user: String) -> Bool { true }

    public func approve(_ user: String, until deadline: Double) -> Bool {
        state.withLock { $0.approved[user] = deadline }
        log("would let \(user) in once without the password")
        return true
    }

    public func revoke(_ user: String) {
        state.withLock { _ = $0.approved.removeValue(forKey: user) }
    }

    public func approval(of user: String) -> Double? {
        state.withLock { $0.approved[user] }
    }
}

public final class DryRunPowerSettings: PowerSettings {
    private let log: Log
    private let womp = OSAllocatedUnfairLock(initialState: false)

    public init(log: Log) {
        self.log = log
    }

    public func mirrorShutdown(at deadline: Double?) {
        log(deadline == nil ? "would cancel the scheduled wake" : "would ask the Mac to wake for the timer")
    }

    public func wakesForNetwork() -> Bool { womp.withLock { $0 } }

    public func setWakesForNetwork(_ on: Bool) -> Bool {
        womp.withLock { $0 = on }
        log("would turn wake for network access \(on ? "on" : "off")")
        return true
    }

    public func stayAwake(_ on: Bool) {
        log(on ? "would keep the Mac awake on power" : "would let the Mac sleep again")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
