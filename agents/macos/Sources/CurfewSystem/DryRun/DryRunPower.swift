public struct DryRunPower: PowerControl {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func perform(_ action: PowerAction) {
        log("would \(action.description)  (\(action.command.joined(separator: " ")))")
    }
}

extension PowerAction {
    var description: String {
        switch self {
        case .poweroff: "power off"
        case .reboot: "restart the computer"
        }
    }

    var command: [String] {
        switch self {
        case .poweroff: ["/sbin/shutdown", "-h", "now"]
        case .reboot: ["/sbin/shutdown", "-r", "now"]
        }
    }
}
