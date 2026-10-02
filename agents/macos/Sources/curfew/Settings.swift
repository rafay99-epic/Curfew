import CurfewAgent
import CurfewControl
import CurfewProtocol
import CurfewSystem
import Foundation

struct Settings: Sendable {
    let dry: Bool
    let port: UInt16
    let stateDirectory: String
    let controlSocket: String
    let fake: String?
    let root: String
    let arguments: [String]

    init(argv: [String], environment: [String: String]) {
        arguments = argv.filter { $0 != "--dry-run" }
        dry = arguments.count != argv.count || environment["CURFEW_DRY"] == "1"
        root = environment["CURFEW_ROOT"] ?? ""
        if dry {
            port = environment["CURFEW_PORT"].flatMap { UInt16($0) } ?? Limits.dryRunPort
            stateDirectory = environment["CURFEW_STATE"].flatMap { $0.isEmpty ? nil : $0 }
                ?? NSHomeDirectory() + "/Library/Application Support/Curfew-dryrun"
            controlSocket = Layout.dryRunSocket(stateDirectory: stateDirectory)
            fake = environment["CURFEW_FAKE"].flatMap { $0.isEmpty ? nil : $0 }
        } else {
            port = Limits.livePort
            stateDirectory = Layout.live.supportDirectory
            controlSocket = Layout.live.controlSocket
            fake = nil
        }
    }

    var log: Log { Log(dry: dry) }

    var store: StateStore { StateStore(directory: stateDirectory) }

    var layout: Layout { Layout(root: root) }

    func system(log: Log) -> SystemServices {
        guard dry else { return .live(log: log) }
        if let fake, let loaded = try? FakeSystem.load(path: fake) {
            return .fake(loaded, log: log)
        }
        return .dryRun(log: log)
    }
}
