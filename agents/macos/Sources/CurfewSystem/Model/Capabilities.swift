public protocol UserDirectory: Sendable {
    func humanUsers() -> [SystemUser]
}

public protocol SessionMonitor: Sendable {
    func sessionStates() -> [String: SessionState]
}

public protocol AppMonitor: Sendable {
    func openApps(of user: SystemUser) -> [OpenApp]
}

public protocol PowerControl: Sendable {
    func perform(_ action: PowerAction)
}

public protocol Notifier: Sendable {
    func notify(_ text: String)
}

public protocol HostInfo: Sendable {
    func hostName() -> String
    func osName() -> String
}

public struct SystemServices: Sendable {
    public let users: any UserDirectory
    public let sessions: any SessionMonitor
    public let apps: any AppMonitor
    public let power: any PowerControl
    public let notifier: any Notifier
    public let host: any HostInfo

    public init(
        users: any UserDirectory,
        sessions: any SessionMonitor,
        apps: any AppMonitor,
        power: any PowerControl,
        notifier: any Notifier,
        host: any HostInfo
    ) {
        self.users = users
        self.sessions = sessions
        self.apps = apps
        self.power = power
        self.notifier = notifier
        self.host = host
    }

    public static func dryRun(log: Log) -> SystemServices {
        SystemServices(
            users: MacUserDirectory(),
            sessions: MacSessionMonitor(),
            apps: MacAppMonitor(),
            power: DryRunPower(log: log),
            notifier: DryRunNotifier(log: log),
            host: MacHost()
        )
    }

    public static func live(log: Log) -> SystemServices {
        SystemServices(
            users: MacUserDirectory(),
            sessions: MacSessionMonitor(),
            apps: MacAppMonitor(),
            power: LivePower(log: log),
            notifier: DryRunNotifier(log: log),
            host: MacHost()
        )
    }

    public static func fake(_ fake: FakeSystem, log: Log) -> SystemServices {
        SystemServices(
            users: fake,
            sessions: fake,
            apps: fake,
            power: DryRunPower(log: log),
            notifier: DryRunNotifier(log: log),
            host: fake
        )
    }
}
