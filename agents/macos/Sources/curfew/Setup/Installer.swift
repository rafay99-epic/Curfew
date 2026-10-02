import CurfewControl
import Darwin
import Foundation

struct CommandRunner: Sendable {
    let run: @Sendable ([String]) -> (status: Int32, output: String)

    static let system = CommandRunner { argv in
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: argv[0])
        process.arguments = Array(argv.dropFirst())
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (127, "\(error)")
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (process.terminationStatus, output)
    }
}

enum InstallError: Error, CustomStringConvertible {
    case file(String, Int32)
    case service(String)
    case notInstalled

    var description: String {
        switch self {
        case .file(let path, let code): "\(path): \(String(cString: strerror(code)))"
        case .service(let output): "launchd refused the service: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .notInstalled: "Curfew is not installed. Run: sudo curfew install"
        }
    }
}

struct Installer {
    static let launchctl = "/bin/launchctl"
    static let firewall = "/usr/libexec/ApplicationFirewall/socketfilterfw"
    static let service = "system/\(Layout.label)"

    let layout: Layout
    let runner: CommandRunner?
    var owned: Bool = geteuid() == 0

    static func launchDaemon(binary: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": Layout.label,
            "ProgramArguments": [binary, "serve"],
            "RunAtLoad": true,
            "KeepAlive": true,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    func install(from source: String) throws -> [String] {
        try makeDirectories(layout.binDirectory)
        try makeDirectories(layout.launchDaemonDirectory)
        try makeDirectories(layout.commandDirectory)
        try copyBinary(from: source)
        try writeFile(layout.launchDaemon, contents: Self.launchDaemon(binary: layout.binary), mode: 0o644)
        var notes = linkCommand()
        if let runner {
            try startService(runner)
            notes += allowThroughFirewall(runner)
        }
        return notes
    }

    func uninstall(purge: Bool) throws {
        if let runner {
            _ = runner.run([Self.launchctl, "bootout", Self.service])
            if FileManager.default.fileExists(atPath: layout.binary) {
                _ = runner.run([Self.firewall, "--remove", layout.binary])
            }
        }
        try remove(layout.launchDaemon)
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: layout.command)) == layout.binary {
            try remove(layout.command)
        }
        try remove(layout.binDirectory)
        if isSocket(layout.controlSocket) {
            try remove(layout.controlSocket)
        }
        if purge {
            try remove(layout.supportDirectory)
        }
    }

    func restart() throws {
        guard FileManager.default.fileExists(atPath: layout.launchDaemon) else { throw InstallError.notInstalled }
        guard let runner else { return }
        _ = runner.run([Self.launchctl, "bootstrap", "system", layout.launchDaemon])
        let started = runner.run([Self.launchctl, "kickstart", "-k", Self.service])
        guard started.status == 0 else { throw InstallError.service(started.output) }
    }

    private func startService(_ runner: CommandRunner) throws {
        _ = runner.run([Self.launchctl, "bootout", Self.service])
        var last = runner.run([Self.launchctl, "bootstrap", "system", layout.launchDaemon])
        var attempts = 1
        while last.status != 0, attempts < 10 {
            usleep(300_000)
            last = runner.run([Self.launchctl, "bootstrap", "system", layout.launchDaemon])
            attempts += 1
        }
        guard last.status == 0 else { throw InstallError.service(last.output) }
    }

    private func allowThroughFirewall(_ runner: CommandRunner) -> [String] {
        guard runner.run([Self.firewall, "--getglobalstate"]).output.contains("enabled") else { return [] }
        let added = runner.run([Self.firewall, "--add", layout.binary]).status == 0
        let unblocked = runner.run([Self.firewall, "--unblockapp", layout.binary]).status == 0
        return added && unblocked ? [] : ["The firewall could not be told to let Curfew in. Allow it in System Settings, Network, Firewall."]
    }

    private func copyBinary(from source: String) throws {
        let target = layout.binary
        let resolved = URL(fileURLWithPath: source).resolvingSymlinksInPath().path
        guard resolved != URL(fileURLWithPath: target).resolvingSymlinksInPath().path else { return }
        guard let contents = FileManager.default.contents(atPath: resolved) else { throw InstallError.file(resolved, errno) }
        try writeFile(target, contents: contents, mode: 0o755)
    }

    private func writeFile(_ path: String, contents: Data, mode: mode_t) throws {
        let temporary = path + ".new"
        unlink(temporary)
        guard FileManager.default.createFile(atPath: temporary, contents: contents) else { throw InstallError.file(temporary, errno) }
        removexattr(temporary, "com.apple.quarantine", XATTR_NOFOLLOW)
        try check(temporary, chmod(temporary, mode))
        if owned {
            try check(temporary, chown(temporary, 0, 0))
        }
        try check(path, rename(temporary, path))
    }

    private func linkCommand() -> [String] {
        let link = layout.command
        var info = stat()
        if lstat(link, &info) == 0 {
            guard info.st_mode & S_IFMT == S_IFLNK else { return ["Left \(link) alone: another file is there."] }
            unlink(link)
        }
        return symlink(layout.binary, link) == 0 ? [] : ["Could not link \(link): \(String(cString: strerror(errno)))"]
    }

    private func makeDirectories(_ path: String) throws {
        var current = ""
        for part in path.split(separator: "/") {
            current += "/" + part
            var info = stat()
            if stat(current, &info) == 0 { continue }
            try check(current, mkdir(current, 0o755))
            try check(current, chmod(current, 0o755))
        }
    }

    private func remove(_ path: String) throws {
        var info = stat()
        guard lstat(path, &info) == 0 else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            throw InstallError.file(path, errno)
        }
    }

    private func isSocket(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0 && info.st_mode & S_IFMT == S_IFSOCK
    }

    private func check(_ path: String, _ result: Int32) throws {
        if result != 0 { throw InstallError.file(path, errno) }
    }
}
