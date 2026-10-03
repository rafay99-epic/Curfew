import CurfewSystem
import Dispatch
import Foundation

public actor TimerScheduler {
    static let firewallRecheck: Double = 60

    private let store: StateStore
    private let system: SystemServices
    private let log: Log
    private var source: (any DispatchSourceTimer)?
    private var mirrored: Double??

    public init(store: StateStore, system: SystemServices, log: Log) {
        self.store = store
        self.system = system
        self.log = log
    }

    public var isArmed: Bool { source != nil }

    public func reschedule() async {
        do {
            let state = try await store.read()
            mirror(state.timer?.deadline)
            arm(Self.nextEvent(state, now: Wall.now()))
        } catch {
            log("timer: could not read the state: \(error)")
        }
    }

    static func nextEvent(_ state: AgentState, now: Double) -> Double? {
        let blocking = state.net.values.contains { $0.blocked == true }
        let events = [state.timer?.nextEvent] + state.net.values.map(\.nextEvent) + [blocking ? now + firewallRecheck : nil]
        return events.compactMap { $0 }.min()
    }

    private func mirror(_ deadline: Double?) {
        guard mirrored != .some(deadline) else { return }
        mirrored = .some(deadline)
        system.settings.mirrorShutdown(at: deadline)
    }

    private func arm(_ event: Double?) {
        guard let event else {
            source?.cancel()
            source = nil
            return
        }
        let timer = source ?? makeSource()
        timer.schedule(wallDeadline: Self.wallTime(max(event, Wall.now())), leeway: .milliseconds(100))
    }

    private func makeSource() -> any DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource()
        timer.setEventHandler { [weak self] in
            Task { await self?.tick() }
        }
        timer.activate()
        source = timer
        return timer
    }

    private struct Due: Sendable {
        var shutdown: CountdownStep?
        var net: [(user: String, step: CountdownStep, warn: Bool)] = []
        var state: AgentState?
    }

    private func tick() async {
        let now = Wall.now()
        do {
            let due = try await store.update { state -> Due in
                var due = Due()
                if let step = state.timer?.step(at: now) {
                    due.shutdown = step
                    if step == .fire { state.timer = nil } else { state.timer?.warned = true }
                }
                for (name, entry) in state.net {
                    guard let step = entry.step(at: now) else { continue }
                    due.net.append((name, step, entry.warn == true))
                    if step == .fire {
                        state.net[name] = AgentState.NetEntry(blocked: true, warn: entry.warn, warned: true)
                    } else {
                        state.net[name]?.warned = true
                    }
                }
                due.state = state
                return due
            }
            if let state = due.state, !system.applyNet(state) {
                log("timer: the firewall could not be updated")
            }
            for item in due.net {
                switch item.step {
                case .warn: system.notifier.notify("The internet will turn off in 1 minute.", user: item.user)
                case .fire:
                    log("internet for \(item.user): off, the countdown reached zero")
                    if item.warn { system.notifier.notify("The internet has been turned off.", user: item.user) }
                }
            }
            switch due.shutdown {
            case .warn?:
                system.notifier.notify("This computer will shut down in 1 minute.")
            case .fire?:
                log("timer reached zero")
                system.power.perform(.poweroff)
            case nil:
                break
            }
        } catch {
            log("timer: could not update the state: \(error)")
        }
        await reschedule()
    }

    private static func wallTime(_ seconds: Double) -> DispatchWallTime {
        let whole = seconds.rounded(.down)
        return DispatchWallTime(timespec: timespec(tv_sec: Int(whole), tv_nsec: Int((seconds - whole) * 1_000_000_000)))
    }
}
