import Foundation

public struct MacSessionControl: SessionControl {
    private let log: Log
    private let tool: String
    private let sessions: any SessionMonitor

    public init(log: Log, tool: String, sessions: any SessionMonitor) {
        self.log = log
        self.tool = tool
        self.sessions = sessions
    }

    public func lock(_ user: SystemUser) -> Bool {
        log("lock the screen of \(user.name)")
        let result = Command.run(["/bin/launchctl", "asuser", String(user.uid), tool, "lock-screen", String(user.uid)])
        if result.status != 0 { log("lock failed: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))") }
        return result.status == 0
    }

    public func logout(_ user: SystemUser) -> Bool {
        log("log out \(user.name)")
        let result = Command.run(["/bin/launchctl", "bootout", "gui/\(user.uid)"])
        for _ in 0..<20 {
            if sessions.sessionStates()[user.name] == nil { return true }
            usleep(250_000)
        }
        log("log out of \(user.name) did not finish: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
        return false
    }
}
