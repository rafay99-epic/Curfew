import Foundation

public struct LivePower: PowerControl {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func perform(_ action: PowerAction) {
        guard geteuid() == 0 else {
            log("refusing to \(action.description): not running as root")
            return
        }
        log(action.description)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: action.command[0])
        process.arguments = Array(action.command.dropFirst())
        do {
            try process.run()
        } catch {
            log("could not \(action.description): \(error)")
        }
    }
}
