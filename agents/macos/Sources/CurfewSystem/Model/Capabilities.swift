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

public protocol SessionControl: Sendable {
    func lock(_ user: SystemUser) -> Bool
    func logout(_ user: SystemUser) -> Bool
}

public protocol Firewall: Sendable {
    func apply(blocked: [SystemUser]) -> Bool
}

public protocol LoginGate: Sendable {
    func isInstalled() -> Bool
    func isEnabled() -> Bool
    func setEnabled(_ on: Bool) -> Bool
    func sync(wanted: Bool) -> Bool
    func knowsPassword(of user: String) -> Bool
    func approve(_ user: String, until deadline: Double) -> Bool
    func revoke(_ user: String)
}

public protocol PowerSettings: Sendable {
    func mirrorShutdown(at deadline: Double?)
    func wakesForNetwork() -> Bool
    func setWakesForNetwork(_ on: Bool) -> Bool
    func stayAwake(_ on: Bool)
}

public protocol Notifier: Sendable {
    func notify(_ text: String, user: String?)
}

extension Notifier {
    public func notify(_ text: String) {
        notify(text, user: nil)
    }
}

public protocol HostInfo: Sendable {
    func hostName() -> String
    func osName() -> String
    func wakeAddress() -> String?
}

public struct SystemServices: Sendable {
    public let users: any UserDirectory
    public let sessions: any SessionMonitor
    public let apps: any AppMonitor
    public let power: any PowerControl
    public let control: any SessionControl
    public let firewall: any Firewall
    public let login: any LoginGate
    public let settings: any PowerSettings
    public let notifier: any Notifier
    public let host: any HostInfo

    public init(
        users: any UserDirectory,
        sessions: any SessionMonitor,
        apps: any AppMonitor,
        power: any PowerControl,
        control: any SessionControl,
        firewall: any Firewall,
        login: any LoginGate,
        settings: any PowerSettings,
        notifier: any Notifier,
        host: any HostInfo
    ) {
        self.users = users
        self.sessions = sessions
        self.apps = apps
        self.power = power
        self.control = control
        self.firewall = firewall
        self.login = login
        self.settings = settings
        self.notifier = notifier
        self.host = host
    }

    public static func dryRun(log: Log) -> SystemServices {
        SystemServices(
            users: MacUserDirectory(),
            sessions: MacSessionMonitor(),
            apps: MacAppMonitor(),
            power: DryRunPower(log: log),
            control: DryRunSessionControl(log: log),
            firewall: DryRunFirewall(log: log),
            login: DryRunLoginGate(log: log),
            settings: DryRunPowerSettings(log: log),
            notifier: DryRunNotifier(log: log),
            host: MacHost()
        )
    }

    public static func live(log: Log, tool: String, supportDirectory: String) -> SystemServices {
        let sessions = MacSessionMonitor()
        return SystemServices(
            users: MacUserDirectory(),
            sessions: sessions,
            apps: MacAppMonitor(),
            power: LivePower(log: log),
            control: MacSessionControl(log: log, tool: tool, sessions: sessions),
            firewall: PacketFilter(log: log, tokenPath: supportDirectory + "/pf.token"),
            login: LoginRights(log: log),
            settings: MacPowerSettings(log: log),
            notifier: ConsoleNotifier(log: log),
            host: MacHost()
        )
    }

    public static func fake(_ fake: FakeSystem, log: Log) -> SystemServices {
        SystemServices(
            users: fake,
            sessions: fake,
            apps: fake,
            power: DryRunPower(log: log),
            control: DryRunSessionControl(log: log),
            firewall: DryRunFirewall(log: log),
            login: DryRunLoginGate(log: log),
            settings: DryRunPowerSettings(log: log),
            notifier: DryRunNotifier(log: log),
            host: fake
        )
    }
}
