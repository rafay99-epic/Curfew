import Foundation
import IOKit

public struct MacSessionMonitor: SessionMonitor {
    public init() {}

    public func sessionStates() -> [String: SessionState] {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard let property = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0),
              let sessions = property.takeRetainedValue() as? [[String: Any]]
        else { return [:] }
        return ConsoleSessions.states(sessions)
    }
}

enum ConsoleSessions {
    static func states(_ sessions: [[String: Any]]) -> [String: SessionState] {
        var states: [String: SessionState] = [:]
        for session in sessions {
            guard let name = session["kCGSSessionUserNameKey"] as? String, !name.isEmpty else { continue }
            let state = state(
                onConsole: session["kCGSSessionOnConsoleKey"] as? Bool ?? false,
                loginDone: session["kCGSessionLoginDoneKey"] as? Bool ?? false,
                screenLocked: session["CGSSessionScreenIsLocked"] as? Bool ?? false
            )
            states[name] = max(states[name] ?? .none, state)
        }
        return states
    }

    static func state(onConsole: Bool, loginDone: Bool, screenLocked: Bool) -> SessionState {
        guard onConsole, loginDone else { return .loggedIn }
        return screenLocked ? .locked : .active
    }
}
