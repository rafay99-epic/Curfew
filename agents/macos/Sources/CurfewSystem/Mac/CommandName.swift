enum CommandName {
    static let wrappers: Set<String> = [
        "env", "nohup", "setsid", "sudo", "time", "nice", "ionice", "exec", "prime-run",
        "gamemoderun", "mangohud", "stdbuf", "torsocks", "firejail", "caffeinate", "arch",
    ]
    static let interpreters: [String: String] = [
        "python": "Python", "python3": "Python", "node": "Node.js", "ruby": "Ruby", "perl": "Perl",
        "bash": "script", "sh": "script", "wine": "Wine", "wine64": "Wine", "mono": "Mono",
    ]
    private static let detailLimit = 140

    static func friendly(_ argv: [String]) -> (name: String, detail: String) {
        var args = argv.isEmpty ? [""] : argv
        while args.count > 1, wrappers.contains(basename(args[0])) || (args[0].split(separator: "/", omittingEmptySubsequences: false).first ?? "").contains("=") {
            args.removeFirst()
            while args.count > 1, args[0].hasPrefix("-") {
                args.removeFirst()
            }
        }
        let stripped = String(basename(args[0]).drop { $0 == "-" })
        let base = stripped.isEmpty ? args[0] : stripped
        let detail = truncated(args.joined(separator: " "))
        let rest = Array(args.dropFirst())
        if base.hasPrefix("java") {
            return (javaName(rest), detail)
        }
        let stem = String(base.reversed().drop { $0.isASCII && ($0.isNumber || $0 == ".") }.reversed())
        if let kind = interpreters[base] ?? interpreters[stem] {
            if let script = rest.first(where: { !$0.hasPrefix("-") }), rest.first != "-c", rest.first != "-m" {
                return ("\(basename(script)) (\(kind))", detail)
            }
            return (kind == "script" ? base : kind, detail)
        }
        return (base, detail)
    }

    static func basename(_ path: String) -> String {
        String(path.split(separator: "/", omittingEmptySubsequences: false).last ?? "")
    }

    private static func javaName(_ arguments: [String]) -> String {
        var rest = arguments
        var index = 0
        while index < rest.count {
            let argument = rest[index]
            if argument == "-jar", index + 1 < rest.count {
                return "\(basename(rest[index + 1])) (Java)"
            }
            if ["-cp", "-classpath", "-p", "--module-path"].contains(argument) {
                if index + 1 < rest.count { rest[index + 1] = "-" } else { rest.append("-") }
            } else if !argument.hasPrefix("-") {
                return "\(argument.split(separator: ".", omittingEmptySubsequences: false).last ?? "") (Java)"
            }
            index += 1
        }
        return "Java program"
    }

    private static func truncated(_ text: String) -> String {
        let scalars = text.unicodeScalars
        guard scalars.count > detailLimit else { return text }
        return String(String.UnicodeScalarView(scalars.prefix(detailLimit - 1))) + "…"
    }
}
