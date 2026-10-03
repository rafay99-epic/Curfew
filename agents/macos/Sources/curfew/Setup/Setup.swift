import Foundation

enum Setup {
    static let commands: Set<String> = ["install", "uninstall", "restart"]

    enum SetupError: Error, CustomStringConvertible {
        case usage

        var description: String { "usage: curfew install [--files-only] | uninstall [--purge] [--files-only] | restart" }
    }

    static func installer(_ settings: Settings, command: String, options: [String]) throws -> Installer {
        let known: Set<String> = command == "uninstall" ? ["--files-only", "--purge"] : command == "install" ? ["--files-only"] : []
        guard Set(options).isSubset(of: known) else { throw SetupError.usage }
        let filesOnly = options.contains("--files-only") || !settings.root.isEmpty
        return Installer(layout: settings.layout, runner: filesOnly ? nil : .system, teardown: filesOnly ? nil : .live(settings.layout))
    }

    static func run(_ settings: Settings, command: String, options: [String]) throws -> Int32 {
        let installer = try installer(settings, command: command, options: options)
        let filesOnly = installer.runner == nil
        switch command {
        case "install":
            let source = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let notes = try installer.install(from: source)
            notes.forEach { print($0) }
            print(filesOnly ? "Installed the files under \(settings.layout.root.isEmpty ? "/" : settings.layout.root)." : "Curfew is running.")
        case "uninstall":
            let purge = options.contains("--purge")
            try installer.uninstall(purge: purge).forEach { print($0) }
            print(purge ? "Curfew is removed, with its paired phones." : "Curfew is removed. Paired phones are kept for a reinstall.")
        default:
            try installer.restart()
            print("Curfew is running.")
        }
        return 0
    }
}
