import Foundation
import IOKit.pwr_mgt
import os

public final class MacPowerSettings: PowerSettings {
    static let owner = "com.rafay99.curfew"
    static let pmset = "/usr/bin/pmset"

    private let log: Log
    private let assertion = OSAllocatedUnfairLock<IOPMAssertionID?>(initialState: nil)

    public init(log: Log) {
        self.log = log
    }

    public func mirrorShutdown(at deadline: Double?) {
        cancelScheduledWakes()
        guard let deadline, deadline > Date().timeIntervalSince1970 + 5 else { return }
        let date = Date(timeIntervalSince1970: deadline) as CFDate
        let result = IOPMSchedulePowerEvent(date, Self.owner as CFString, kIOPMAutoWake as CFString)
        if result != kIOReturnSuccess { log("could not ask the Mac to wake for the timer: \(result)") }
    }

    public func wakesForNetwork() -> Bool {
        Self.womp(in: Command.run([Self.pmset, "-g"]).output) == true
    }

    public func setWakesForNetwork(_ on: Bool) -> Bool {
        let done = Command.run([Self.pmset, "-a", "womp", on ? "1" : "0"]).status == 0
        log(done ? "wake for the phone is \(on ? "on" : "off")" : "pmset refused to change wake for network access")
        return done
    }

    public func stayAwake(_ on: Bool) {
        assertion.withLock { held in
            if on, held == nil {
                var id = IOPMAssertionID(0)
                let name = "Curfew keeps this Mac awake on power so the phone can reach it" as CFString
                if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name, &id) == kIOReturnSuccess {
                    held = id
                }
            } else if !on, let id = held {
                IOPMAssertionRelease(id)
                held = nil
            }
        }
    }

    private func cancelScheduledWakes() {
        guard let events = IOPMCopyScheduledPowerEvents()?.takeRetainedValue() as? [[String: Any]] else { return }
        for event in events where event[kIOPMPowerEventAppNameKey] as? String == Self.owner {
            guard let time = event[kIOPMPowerEventTimeKey] as? Date, let type = event[kIOPMPowerEventTypeKey] as? String else { continue }
            IOPMCancelScheduledPowerEvent(time as CFDate, Self.owner as CFString, type as CFString)
        }
    }

    static func womp(in output: String) -> Bool? {
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            if parts.count >= 2, parts[0] == "womp" { return parts[1] == "1" }
        }
        return nil
    }
}
