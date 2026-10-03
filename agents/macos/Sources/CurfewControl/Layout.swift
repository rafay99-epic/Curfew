public struct Layout: Sendable, Equatable {
    public static let label = "com.rafay99.curfew"
    public static let live = Layout(root: "")

    public let root: String

    public init(root: String) {
        self.root = root.hasSuffix("/") ? String(root.dropLast()) : root
    }

    public var supportDirectory: String { root + "/Library/Application Support/Curfew" }
    public var binDirectory: String { supportDirectory + "/bin" }
    public var binary: String { binDirectory + "/curfew" }
    public var launchDaemonDirectory: String { root + "/Library/LaunchDaemons" }
    public var launchDaemon: String { launchDaemonDirectory + "/\(Self.label).plist" }
    public var commandDirectory: String { root + "/usr/local/bin" }
    public var command: String { commandDirectory + "/curfew" }
    public var controlSocket: String { root + "/var/run/curfew.sock" }
    public var loginDirectory: String { supportDirectory + "/Login" }
    public var pluginDirectory: String { root + "/Library/Security/SecurityAgentPlugins" }
    public var plugin: String { pluginDirectory + "/CurfewLogin.bundle" }

    public static func dryRunSocket(stateDirectory: String) -> String {
        stateDirectory + "/control.sock"
    }
}
