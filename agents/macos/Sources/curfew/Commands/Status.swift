import CurfewAgent
import CurfewProtocol
import CurfewSystem
import Foundation

enum Status {
    static func run(_ settings: Settings) async throws -> Int32 {
        let log = settings.log
        let agent = Agent(store: settings.store, system: settings.system(log: log), log: log)
        let report = try await agent.statusReport()
        let phones = try await agent.store.read().phones.count
        let running = LocalNetwork.agentRunning(port: settings.port) ? "running" : "NOT running"
        print("Curfew agent \(report["id"]?.string ?? "") on \(report["name"]?.string ?? "") (\(report["os"]?.string ?? "")), port \(settings.port), \(running)")
        print("Paired phones: \(phones)")
        if let remaining = report["timer"]?["remaining"]?.integer {
            print(String(format: "Shut-down timer: %ld min %02ld s left", remaining / 60, remaining % 60))
        } else {
            print("Shut-down timer: none")
        }
        guard case .array(let users)? = report["users"] else { return 0 }
        for user in users {
            let name = user["name"]?.string ?? ""
            let kind = user["admin"] == .bool(true) ? "admin" : "standard"
            let state = (user["state"]?.string ?? "").replacingOccurrences(of: "_", with: " ")
            print("  \(Phones.pad(name, 20)) \(Phones.pad(kind, 9)) \(state)")
        }
        return 0
    }
}
