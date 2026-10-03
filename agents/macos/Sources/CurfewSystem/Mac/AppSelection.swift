enum AppSelection {
    static let limit = 15
    static let shells: Set<String> = [
        "bash", "zsh", "sh", "dash", "fish", "ksh", "tcsh", "csh", "nu", "xonsh", "login",
        "tmux", "tmux: server", "tmux: client", "screen", "script", "sudo", "su", "ssh-agent", "gpg-agent",
        "less", "man", "pager", "more",
    ]
    static let helpers: Set<String> = [
        "sleep", "tail", "head", "cat", "tee", "grep", "sed", "awk", "wc", "sort", "cut", "tr", "xargs",
        "timeout", "true", "false", "echo", "printf", "date", "env", "ls", "ps", "find", "which", "watch",
    ]
    static let terminalNoise = ["gitstatusd", "ssh-agent", "gpg-agent", "dbus-", "fzf", "starship", "direnv", "zoxide", "atuin"]
    static let minecraftMarkers = ["minecraft", "tlauncher", "launchwrapper", "multimc", "prismlauncher", "lunarclient", "badlion"]

    static func select(_ processes: [ProcessRecord], now: Int, desktopName: (ProcessRecord) -> String?) -> [OpenApp] {
        var found = Found()
        let candidates = Set(processes.filter(isTerminalProgram).map(\.pid))
        let tree = Tree(processes)
        for process in processes where candidates.contains(process.pid) && !candidates.contains(process.ppid) {
            var (name, detail) = CommandName.friendly(process.arguments)
            let text = tree.text(of: process.pid).lowercased()
            if minecraftMarkers.contains(where: text.contains) {
                name = "Minecraft"
            }
            found.add(OpenApp(name: name, detail: detail, age: age(process, now), terminal: true))
        }
        for process in processes where !process.hasTerminal {
            guard let name = desktopName(process) else { continue }
            found.add(OpenApp(name: name, detail: "", age: age(process, now), terminal: false))
        }
        return Array(found.apps.sorted { $0.age < $1.age }.prefix(limit))
    }

    private static func age(_ process: ProcessRecord, _ now: Int) -> Int {
        max(0, now - process.start)
    }

    private static func isTerminalProgram(_ process: ProcessRecord) -> Bool {
        guard process.hasTerminal else { return false }
        let plain = String(CommandName.basename(process.arguments.first ?? process.comm).drop { $0 == "-" })
        return !shells.contains(process.comm)
            && !terminalNoise.contains(where: process.comm.hasPrefix)
            && !shells.contains(plain)
            && !helpers.contains(plain)
    }

    private struct Found {
        private(set) var apps: [OpenApp] = []
        private var index: [String: Int] = [:]

        mutating func add(_ app: OpenApp) {
            guard let at = index[app.name] else {
                index[app.name] = apps.count
                apps.append(app)
                return
            }
            if app.age > apps[at].age {
                apps[at] = app
            }
        }
    }

    private struct Tree {
        private let byPid: [Int32: ProcessRecord]
        private let children: [Int32: [Int32]]

        init(_ processes: [ProcessRecord]) {
            byPid = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
            children = Dictionary(grouping: processes, by: \.ppid).mapValues { $0.map(\.pid) }
        }

        func text(of pid: Int32, depth: Int = 0) -> String {
            guard let process = byPid[pid] else { return "" }
            var text = process.arguments.joined(separator: " ")
            if depth < 4 {
                for child in (children[pid] ?? []).prefix(20) {
                    text += " " + self.text(of: child, depth: depth + 1)
                }
            }
            return text
        }
    }
}
