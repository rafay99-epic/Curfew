import Foundation

public struct PacketFilter: Firewall {
    public static let anchor = "com.apple/curfew"
    static let pfctl = "/sbin/pfctl"

    private let log: Log
    private let tokenPath: String
    private let run: @Sendable ([String], String?) -> CommandResult

    public init(log: Log, tokenPath: String, run: @escaping @Sendable ([String], String?) -> CommandResult = Command.run) {
        self.log = log
        self.tokenPath = tokenPath
        self.run = run
    }

    public static func rules(for uids: [uid_t]) -> String {
        Set(uids).sorted().map { "block return out quick on ! lo0 proto { tcp udp } all user \($0)\n" }.joined()
    }

    public static func token(in output: String) -> String? {
        output.split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("Token") }?
            .split(separator: ":").last?
            .trimmingCharacters(in: .whitespaces)
    }

    public func apply(blocked users: [SystemUser]) -> Bool {
        let uids = users.filter { !$0.admin }.map(\.uid)
        guard !uids.isEmpty else { return release() }
        let rules = Self.rules(for: uids)
        let loaded = run([Self.pfctl, "-a", Self.anchor, "-s", "rules"], nil).output
        if !Self.sameRules(loaded, rules) {
            log("pf: internet off for \(users.filter { !$0.admin }.map(\.name).joined(separator: ", "))")
            guard run([Self.pfctl, "-a", Self.anchor, "-f", "-"], rules).status == 0 else {
                log("pf: the rules were not accepted")
                return false
            }
        }
        return enable()
    }

    private func enable() -> Bool {
        let held = savedToken()
        if held != nil, run([Self.pfctl, "-s", "info"], nil).output.contains("Status: Enabled") { return true }
        let answer = run([Self.pfctl, "-E"], nil)
        guard answer.status == 0, let token = Self.token(in: answer.output) else {
            log("pf: could not be turned on: \(answer.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            return false
        }
        if let held { _ = run([Self.pfctl, "-X", held], nil) }
        FileManager.default.createFile(atPath: tokenPath, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600])
        return true
    }

    private func release() -> Bool {
        let held = savedToken()
        guard held != nil || run([Self.pfctl, "-a", Self.anchor, "-s", "rules"], nil).output.contains("block") else { return true }
        log("pf: internet on for everyone")
        let flushed = run([Self.pfctl, "-a", Self.anchor, "-F", "rules"], nil).status == 0
        if let held {
            _ = run([Self.pfctl, "-X", held], nil)
            unlink(tokenPath)
        }
        return flushed
    }

    private func savedToken() -> String? {
        FileManager.default.contents(atPath: tokenPath)
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty || !$0.allSatisfy(\.isNumber) ? nil : $0 }
    }

    static func sameRules(_ loaded: String, _ wanted: String) -> Bool {
        func users(_ text: String) -> Set<String> {
            Set(text.split(whereSeparator: \.isNewline).compactMap { line in
                line.contains("block return out quick") ? line.split(separator: " ").last.map(String.init) : nil
            })
        }
        let want = users(wanted)
        return !want.isEmpty && users(loaded) == want
    }
}
