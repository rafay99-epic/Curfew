@testable import CurfewSystem
import Foundation
import os
import Testing

final class FakePfctl: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (calls: [[String]](), rules: "", enabled: false))

    var run: @Sendable ([String], String?) -> CommandResult {
        { [state] argv, input in
            state.withLock { s in
                s.calls.append(Array(argv.dropFirst()))
                switch Array(argv.dropFirst()) {
                case ["-a", PacketFilter.anchor, "-s", "rules"]:
                    return CommandResult(status: 0, output: s.rules.replacingOccurrences(of: "proto { tcp udp } all user ", with: "proto tcp all user = "))
                case ["-a", PacketFilter.anchor, "-f", "-"]:
                    s.rules = input ?? ""
                    return CommandResult(status: 0, output: "")
                case ["-a", PacketFilter.anchor, "-F", "rules"]:
                    s.rules = ""
                    return CommandResult(status: 0, output: "")
                case ["-s", "info"]:
                    return CommandResult(status: 0, output: s.enabled ? "Status: Enabled for 0 days" : "Status: Disabled")
                case ["-E"]:
                    s.enabled = true
                    return CommandResult(status: 0, output: "pf enabled\nToken : 14862827186\n")
                default:
                    if argv.dropFirst().first == "-X" { s.enabled = false }
                    return CommandResult(status: 0, output: "")
                }
            }
        }
    }

    var calls: [[String]] { state.withLock { $0.calls } }
    var rules: String { state.withLock { $0.rules } }
}

@Suite struct PacketFilterTests {
    let token = NSTemporaryDirectory() + "cf-pf-" + UUID().uuidString

    func user(_ name: String, _ uid: uid_t, admin: Bool = false) -> SystemUser {
        SystemUser(name: name, full: name, admin: admin, uid: uid)
    }

    @Test func rulesBlockEachAccountOnce() {
        #expect(PacketFilter.rules(for: [503, 502, 503]) == """
            block return out quick on ! lo0 proto { tcp udp } all user 502
            block return out quick on ! lo0 proto { tcp udp } all user 503

            """)
        #expect(PacketFilter.token(in: "No ALTQ support in kernel\npf enabled\nToken : 14862827186\n") == "14862827186")
        #expect(PacketFilter.token(in: "pf enabled") == nil)
    }

    @Test func blockingTurnsPfOnWithATokenAndReleasingGivesItBack() {
        defer { unlink(token) }
        let pfctl = FakePfctl()
        let filter = PacketFilter(log: Log(dry: false) { _ in }, tokenPath: token, run: pfctl.run)
        #expect(filter.apply(blocked: [user("ali", 502), user("dad", 501, admin: true)]))
        #expect(pfctl.rules == PacketFilter.rules(for: [502]))
        #expect(FileManager.default.contents(atPath: token) == Data("14862827186".utf8))
        let before = pfctl.calls.count
        #expect(filter.apply(blocked: [user("ali", 502)]))
        #expect(!pfctl.calls[before...].contains(["-a", PacketFilter.anchor, "-f", "-"]))
        #expect(!pfctl.calls[before...].contains(["-E"]))
        #expect(filter.apply(blocked: []))
        #expect(pfctl.rules.isEmpty)
        #expect(pfctl.calls.contains(["-X", "14862827186"]))
        #expect(!FileManager.default.fileExists(atPath: token))
    }

    @Test func nothingBlockedOnACleanMacTouchesNothing() {
        let pfctl = FakePfctl()
        let filter = PacketFilter(log: Log(dry: false) { _ in }, tokenPath: token, run: pfctl.run)
        #expect(filter.apply(blocked: [user("dad", 501, admin: true)]))
        #expect(pfctl.calls == [["-a", PacketFilter.anchor, "-s", "rules"]])
    }

    @Test func wompIsReadFromPmset() {
        #expect(MacPowerSettings.womp(in: " sleep 1\n womp                 1\n") == true)
        #expect(MacPowerSettings.womp(in: " womp 0") == false)
        #expect(MacPowerSettings.womp(in: " sleep 1") == nil)
    }
}
