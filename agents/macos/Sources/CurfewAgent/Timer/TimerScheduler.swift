import CurfewSystem
import Dispatch
import Foundation

public actor TimerScheduler {
    private let store: StateStore
    private let system: SystemServices
    private let log: Log
    private var source: (any DispatchSourceTimer)?

    public init(store: StateStore, system: SystemServices, log: Log) {
        self.store = store
        self.system = system
        self.log = log
    }

    public var isArmed: Bool { source != nil }

    public func reschedule() async {
        do {
            arm(try await store.read().timer)
        } catch {
            log("timer: could not read the state: \(error)")
        }
    }

    private func arm(_ countdown: AgentState.Countdown?) {
        guard let countdown else {
            source?.cancel()
            source = nil
            return
        }
        let timer = source ?? makeSource()
        timer.schedule(wallDeadline: Self.wallTime(max(countdown.nextEvent, Wall.now())), leeway: .milliseconds(100))
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

    private func tick() async {
        let now = Wall.now()
        do {
            let step = try await store.update { state -> CountdownStep? in
                guard let countdown = state.timer, let step = countdown.step(at: now) else { return nil }
                switch step {
                case .fire: state.timer = nil
                case .warn: state.timer?.warned = true
                }
                return step
            }
            switch step {
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
