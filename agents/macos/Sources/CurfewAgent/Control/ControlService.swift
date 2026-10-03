import CurfewControl
import CurfewProtocol
import CurfewSystem

public actor ControlService {
    private let store: StateStore
    private let system: SystemServices
    private let port: UInt16
    private let dry: Bool
    private let log: Log
    private let lanAddress: @Sendable () -> String?
    private var watched: (code: String, started: Double)?

    public init(
        store: StateStore, system: SystemServices, port: UInt16, dry: Bool, log: Log,
        lanAddress: @escaping @Sendable () -> String? = LocalNetwork.lanAddress
    ) {
        self.store = store
        self.system = system
        self.port = port
        self.dry = dry
        self.log = log
        self.lanAddress = lanAddress
    }

    public func respond(to line: String) async -> String {
        guard let json = JSONValue(parsing: line), let request = ControlRequest(json) else {
            return ControlError.badRequest.json.text
        }
        do {
            return try await handle(request).text
        } catch let error as ControlError {
            return error.json.text
        } catch {
            log("control: \(error)")
            return ControlError.failed.json.text
        }
    }

    private func handle(_ request: ControlRequest) async throws -> JSONValue {
        switch request {
        case .status:
            return try await status().json
        case .pairStart:
            return try await startPairing()
        case .pairStatus(let code):
            let state = try await store.read()
            let started = watched.flatMap { $0.code == code ? $0.started : nil } ?? .infinity
            return state.pairingProgress(code: code, since: started, now: Wall.now()).json
        case .pairCancel(let code):
            try await store.update { $0.withdrawPairing(code: code) }
            return ["ok": true]
        case .unpair(let id):
            let now = Int(Wall.now())
            guard let phone = try await store.update({ $0.removePhone(id, now: now) }) else { throw ControlError.noPhone }
            log("removed phone \"\(phone.name)\"")
            return ["ok": true, "name": .string(phone.name)]
        case .set(let setting, let on):
            try apply(setting, on)
            try await store.update { state in
                switch setting {
                case .login: state.settings.login = on
                case .wake: state.settings.wake = on
                case .awake: state.settings.awake = on
                }
            }
            return ["ok": true]
        }
    }

    private func apply(_ setting: ControlSetting, _ on: Bool) throws {
        switch setting {
        case .login:
            guard system.login.setEnabled(on) else { throw on ? ControlError.loginUnavailable : ControlError.failed }
        case .wake:
            guard system.settings.setWakesForNetwork(on) else { throw ControlError.failed }
        case .awake:
            system.settings.stayAwake(on)
        }
    }

    private func status() async throws -> ControlStatus {
        let state = try await store.read()
        let phones = state.orderedPhones.map { ControlPhone(id: $0.id, name: $0.phone.name, pairedAt: $0.phone.added) }
        let settings = ControlSettings(
            login: state.settings.login, loginReady: system.login.isInstalled(), wake: state.settings.wake, awake: state.settings.awake
        )
        return ControlStatus(
            name: system.host.hostName(), version: CurfewVersion.current, dry: dry, phones: phones,
            pairing: openOffer(in: state), settings: settings
        )
    }

    private func openOffer(in state: AgentState) -> PairingOffer? {
        let now = Wall.now()
        guard let pairing = state.pairing, pairing.expires >= now, let ip = lanAddress() else { return nil }
        if watched?.code != pairing.code {
            watched = (pairing.code, pairing.expires - PairingCode.lifetime)
        }
        return PairingOffer(address: "\(ip):\(port)", agent: state.id, code: pairing.code, expiresIn: Int((pairing.expires - now).rounded(.up)))
    }

    private func startPairing() async throws -> JSONValue {
        guard let ip = lanAddress() else { throw ControlError.noNetwork }
        let code = PairingCode.generate()
        let now = Wall.now()
        let id = try await store.update { state in
            state.offerPairing(code: code, now: now)
            return state.id
        }
        watched = (code, now)
        let offer = PairingOffer(address: "\(ip):\(port)", agent: id, code: code, expiresIn: Int(PairingCode.lifetime))
        return .object([JSONMember("ok", true)] + offer.members)
    }
}
