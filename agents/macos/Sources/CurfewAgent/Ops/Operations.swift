import CurfewProtocol
import CurfewSystem
import Foundation

struct Operations: Sendable {
    static let maxSeconds = 86400
    static let loginSeconds = 120

    let store: StateStore
    let system: SystemServices
    let scheduler: TimerScheduler
    let log: Log

    func run(_ body: JSONValue, phone: String, state: AgentState) async -> JSONValue {
        guard body.isObject else { return OpError.badRequest.body }
        switch OpLookup(body["op"]) {
        case .malformed: return OpError.badRequest.body
        case .unknown: return OpError.badOp.body
        case .known(let op):
            do {
                return try await run(op, body, phone: phone, state: state)
            } catch {
                log("error in request: \(error)")
                return OpError.failed.body
            }
        }
    }

    private func run(_ op: Op, _ body: JSONValue, phone: String, state: AgentState) async throws -> JSONValue {
        switch op {
        case .status: return status(state)
        case .apps: return apps(body)
        case .poweroff, .reboot: return power(op == .reboot ? .reboot : .poweroff)
        case .timerSet: return try await timerSet(body)
        case .timerCancel: return try await timerCancel()
        case .forget: return try await forget(phone)
        case .lock: return lock(body)
        case .logout: return logout(body)
        case .login: return login(body, state: state, phone: phone)
        case .netSet: return try await netSet(body)
        case .netClear: return try await netClear(body)
        }
    }

    func users() -> [(user: SystemUser, state: SessionState)] {
        let states = system.sessions.sessionStates()
        return system.users.humanUsers().map { ($0, states[$0.name] ?? .none) }
    }

    static func capabilities(_ state: AgentState) -> [JSONValue] {
        ["seconds", "net"] + (state.settings.login ? ["login"] : [])
    }

    func status(_ state: AgentState) -> JSONValue {
        let now = Wall.now()
        let list = users().map { user, session -> JSONValue in
            let entry = state.net[user.name]
            var members = [
                JSONMember("name", .string(user.name)),
                JSONMember("full", .string(user.full)),
                JSONMember("admin", .bool(user.admin)),
                JSONMember("state", .string(session.rawValue)),
                JSONMember("net", .string(entry?.blocked == true && !user.admin ? "off" : "on")),
            ]
            if let deadline = entry?.deadline, !user.admin {
                members.append(JSONMember("net_timer", [
                    "remaining": .int(max(0, Int(deadline - now))),
                    "warn": .bool(entry?.warn ?? false),
                ]))
            }
            return .object(members)
        }
        let timer: JSONValue = state.timer.map {
            ["remaining": .int($0.remaining(at: now)), "warn": .bool($0.warn)]
        } ?? .null
        var members = [
            JSONMember("ok", true),
            JSONMember("id", .string(state.id)),
            JSONMember("name", .string(system.host.hostName())),
            JSONMember("os", .string(system.host.osName())),
            JSONMember("users", .array(list)),
            JSONMember("timer", timer),
            JSONMember("caps", .array(Self.capabilities(state))),
            JSONMember("dry", .bool(log.dry)),
        ]
        if state.settings.wake, let wake = system.host.wakeAddress() {
            members.append(JSONMember("wake", .string(wake)))
        }
        return .object(members)
    }

    private func find(_ body: JSONValue) -> (user: SystemUser, state: SessionState)? {
        guard let name = body["user"]?.string else { return nil }
        return users().first { $0.user.name == name }
    }

    private func apps(_ body: JSONValue) -> JSONValue {
        guard let user = find(body)?.user else { return OpError.badUser.body }
        let apps = system.apps.openApps(of: user).map { app -> JSONValue in
            [
                "name": .string(app.name),
                "detail": .string(app.detail),
                "age": .int(app.age),
                "terminal": .bool(app.terminal),
            ]
        }
        return ["ok": true, "apps": .array(apps)]
    }

    private func power(_ action: PowerAction) -> JSONValue {
        let power = system.power
        Task.detached {
            try? await Task.sleep(for: .seconds(1))
            power.perform(action)
        }
        return ["ok": true]
    }

    private func timerSet(_ body: JSONValue) async throws -> JSONValue {
        guard let seconds = Self.countdown(body) else { return OpError.badArgs.body }
        let warn = body["warn"]?.truthy ?? false
        let deadline = Wall.now() + Double(seconds)
        try await store.update { state in
            state.timer = AgentState.Countdown(deadline: deadline, warn: warn, warned: seconds <= 60)
        }
        log("timer set: shut down in \(HumanDuration.text(seconds))")
        await scheduler.reschedule()
        if warn {
            system.notifier.notify("This computer will shut down in \(HumanDuration.text(seconds)).")
        }
        return ["ok": true, "timer": ["remaining": .int(seconds), "warn": .bool(warn)]]
    }

    private func timerCancel() async throws -> JSONValue {
        try await store.update { $0.timer = nil }
        log("timer cancelled")
        await scheduler.reschedule()
        return ["ok": true, "timer": .null]
    }

    private func forget(_ phone: String) async throws -> JSONValue {
        let gone = try await store.update { $0.phones.removeValue(forKey: phone) }
        log("phone \"\(gone?.name ?? "")\" removed itself")
        return ["ok": true]
    }

    private func lock(_ body: JSONValue) -> JSONValue {
        guard let (user, session) = find(body) else { return OpError.badUser.body }
        system.login.revoke(user.name)
        switch session {
        case .none: return OpError.notLoggedIn.body
        case .loggedIn, .locked: return ["ok": true]
        case .active: return system.control.lock(user) ? ["ok": true] : OpError.failed.body
        }
    }

    private func logout(_ body: JSONValue) -> JSONValue {
        guard let (user, session) = find(body) else { return OpError.badUser.body }
        system.login.revoke(user.name)
        guard session != .none else { return OpError.notLoggedIn.body }
        return system.control.logout(user) ? ["ok": true] : OpError.failed.body
    }

    private func login(_ body: JSONValue, state: AgentState, phone: String) -> JSONValue {
        guard let (user, session) = find(body) else { return OpError.badUser.body }
        guard state.settings.login else { return OpError.unsupported.body }
        if session == .active { return ["ok": true, "how": "unlocked", "seconds": .int(Self.loginSeconds)] }
        guard system.login.knowsPassword(of: user.name) else { return OpError.noPassword.body }
        guard system.login.approve(user.name, until: Wall.now() + Double(Self.loginSeconds)) else { return OpError.failed.body }
        log("login approved for \(user.name) by phone \"\(state.phones[phone]?.name ?? "")\"")
        return ["ok": true, "how": "approved", "seconds": .int(Self.loginSeconds)]
    }

    private func netSet(_ body: JSONValue) async throws -> JSONValue {
        guard let (user, _) = find(body) else { return OpError.badUser.body }
        guard !user.admin else { return OpError.isAdmin.body }
        guard let seconds = Self.countdown(body, minimum: 0), seconds == 0 || seconds >= 10 else { return OpError.badArgs.body }
        let warn = body["warn"]?.truthy ?? false
        let now = Wall.now()
        let entry = AgentState.NetEntry(
            blocked: seconds == 0, deadline: seconds == 0 ? nil : now + Double(seconds), warn: warn, warned: seconds <= 60
        )
        let (old, state) = try await store.update { state in
            let old = state.net[user.name]
            state.net[user.name] = entry
            return (old, state)
        }
        guard system.applyNet(state) else {
            let restored = try await store.update { state in
                state.net[user.name] = old
                return state
            }
            _ = system.applyNet(restored)
            return OpError.failed.body
        }
        log("internet for \(user.name): off \(seconds == 0 ? "now" : "in " + HumanDuration.text(seconds))")
        await scheduler.reschedule()
        if warn {
            let text = seconds == 0 ? "The internet has been turned off." : "The internet will turn off in \(HumanDuration.text(seconds))."
            system.notifier.notify(text, user: user.name)
        }
        return ["ok": true]
    }

    private func netClear(_ body: JSONValue) async throws -> JSONValue {
        guard let (user, _) = find(body) else { return OpError.badUser.body }
        let state = try await store.update { state in
            state.net.removeValue(forKey: user.name)
            return state
        }
        let ok = system.applyNet(state)
        log("internet for \(user.name): on")
        await scheduler.reschedule()
        return ok ? ["ok": true] : OpError.failed.body
    }

    static func countdown(_ body: JSONValue, minimum: Int = 10) -> Int? {
        var value = body["seconds"]
        if value == nil || value == .null {
            guard let minutes = body["minutes"]?.integer else { return nil }
            let (product, overflow) = minutes.multipliedReportingOverflow(by: 60)
            guard !overflow else { return nil }
            value = .int(product)
        }
        guard let seconds = value?.integer, (minimum...maxSeconds).contains(seconds) else { return nil }
        return seconds
    }
}

extension SystemServices {
    func applyNet(_ state: AgentState) -> Bool {
        let off = Set(state.net.filter { $0.value.blocked == true }.keys)
        return firewall.apply(blocked: users.humanUsers().filter { off.contains($0.name) && !$0.admin })
    }
}
