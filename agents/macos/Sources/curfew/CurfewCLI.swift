import CurfewSystem
import Darwin
import Dispatch
import Foundation

@main
enum CurfewCLI {
    static let usage = """
        Curfew - control this computer from a paired phone.

          sudo curfew pair            show a QR code to pair a phone
          sudo curfew phones          list paired phones
          sudo curfew unpair NAME     remove a phone (name or number from the list)
          sudo curfew status          show the agent, timer and users
          sudo curfew id              print this agent's id

          sudo curfew install         set up the background service on this Mac
          sudo curfew uninstall       remove it (add --purge to also forget the phones)
          sudo curfew restart         start the background service again

          curfew serve --dry-run [--port N] [--bind 127.0.0.1] [--bonjour]
        """

    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        umask(0o077)
        let settings = Settings(argv: Array(CommandLine.arguments.dropFirst()), environment: ProcessInfo.processInfo.environment)
        Task {
            exit(await run(settings))
        }
        dispatchMain()
    }

    static func run(_ settings: Settings) async -> Int32 {
        let args = settings.arguments
        let command = args.first ?? "help"
        if ["help", "-h", "--help"].contains(command) {
            print(usage)
            return 0
        }
        if command == "lock-screen", args.count == 2, let uid = uid_t(args[1]) {
            return geteuid() == 0 && ScreenLock.lockAs(uid: uid) ? 0 : 1
        }
        let testRoot = Setup.commands.contains(command) && !settings.root.isEmpty
        if !settings.dry && !testRoot && geteuid() != 0 {
            print("This needs administrator rights. Run it as: sudo curfew " + args.joined(separator: " "))
            return 1
        }
        do {
            switch (command, args.count) {
            case ("serve", _): return try await Serve.run(settings, options: Array(args.dropFirst()))
            case (let setup, _) where Setup.commands.contains(setup): return try Setup.run(settings, command: setup, options: Array(args.dropFirst()))
            case ("pair", 1): return try await Pair.run(settings)
            case ("phones", 1): return try await Phones.list(settings)
            case ("unpair", 2...): return try await Phones.unpair(settings, who: args.dropFirst().joined(separator: " "))
            case ("status", 1): return try await Status.run(settings)
            case ("id", 1):
                print(try await settings.store.read().id)
                return 0
            default:
                print(usage)
                return 1
            }
        } catch {
            FileHandle.standardError.write(Data("curfew: \(error)\n".utf8))
            return 1
        }
    }
}
