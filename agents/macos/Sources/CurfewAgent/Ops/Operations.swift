import CurfewProtocol
import CurfewSystem
import Foundation

struct Operations: Sendable {
    static let capabilities: [JSONValue] = ["seconds"]
    static let maxSeconds = 86400

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
        case .lock, .logout, .login, .netSet, .netClear: return OpError.unsupported.body
        }
    }

    func users() -> [(user: SystemUser, state: SessionState)] {
        let states = system.sessions.sessionStates()
        return system.users.humanUsers().map { ($0, states[$0.name] ?? .none) }
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
        return [
            "ok": true,
            "id": .string(state.id),
            "name": .string(system.host.hostName()),
            "os": .string(system.host.osName()),
            "users": .array(list),
            "timer": timer,
            "caps": .array(Self.capabilities),
            "dry": .bool(log.dry),
        ]
    }

    private func apps(_ body: JSONValue) -> JSONValue {
        guard let name = body["user"]?.string,
              let user = system.users.humanUsers().first(where: { $0.name == name })
        else { return OpError.badUser.body }
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
