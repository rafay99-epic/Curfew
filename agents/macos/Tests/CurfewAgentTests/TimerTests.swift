@testable import CurfewAgent
import CurfewProtocol
import Testing

@Suite struct TimerTests {
    @Test func countdownSteps() {
        let countdown = AgentState.Countdown(deadline: 1000, warn: true, warned: false)
        #expect(countdown.step(at: 900) == nil)
        #expect(countdown.nextEvent == 940)
        #expect(countdown.step(at: 940) == .warn)
        #expect(countdown.step(at: 1000) == .fire)
        let warned = AgentState.Countdown(deadline: 1000, warn: true, warned: true)
        #expect(warned.step(at: 950) == nil)
        #expect(warned.nextEvent == 1000)
        #expect(warned.remaining(at: 1500) == 0)
    }

    @Test func noDeadlineMeansNoTimerArmed() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        await harness.agent.start()
        #expect(await !harness.agent.scheduler.isArmed)
    }

    @Test func deadlineSetBeforeStartFiresOnceAfterStart() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.store.update { $0.timer = AgentState.Countdown(deadline: Wall.now() + 1, warn: false, warned: true) }
        await harness.agent.start()
        #expect(await harness.agent.scheduler.isArmed)
        try await Task.sleep(for: .milliseconds(2000))
        let log = harness.recorder.text
        #expect(log.contains("timer reached zero"))
        #expect(log.components(separatedBy: "would power off  (/sbin/shutdown -h now)").count == 2)
        #expect(try await harness.store.read().timer == nil)
        #expect(await !harness.agent.scheduler.isArmed)
    }

    @Test func pastDeadlineFiresImmediately() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.store.update { $0.timer = AgentState.Countdown(deadline: Wall.now() - 30, warn: true, warned: false) }
        await harness.agent.start()
        try await Task.sleep(for: .milliseconds(500))
        #expect(harness.recorder.text.contains("would power off"))
        #expect(!harness.recorder.text.contains("would notify"))
    }

    @Test func warnsOneMinuteBeforeTheEnd() async throws {
        let harness = Harness()
        defer { harness.cleanUp() }
        try await harness.store.update { $0.timer = AgentState.Countdown(deadline: Wall.now() + 61, warn: true, warned: false) }
        await harness.agent.start()
        try await Task.sleep(for: .milliseconds(1800))
        #expect(harness.recorder.text.contains("would notify: This computer will shut down in 1 minute."))
        #expect(try await harness.store.read().timer?.warned == true)
        #expect(!harness.recorder.text.contains("would power off"))
        #expect(await harness.agent.scheduler.isArmed)
        try await harness.store.update { $0.timer = nil }
        await harness.agent.scheduler.reschedule()
        #expect(await !harness.agent.scheduler.isArmed)
    }
}
