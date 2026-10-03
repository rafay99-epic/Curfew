import CurfewProtocol
import CurfewSystem

public final class Agent: Sendable {
    public let store: StateStore
    public let scheduler: TimerScheduler
    let system: SystemServices
    let log: Log
    let nonces = NonceBook()
    let operations: Operations

    public init(store: StateStore, system: SystemServices, log: Log) {
        self.store = store
        self.system = system
        self.log = log
        scheduler = TimerScheduler(store: store, system: system, log: log)
        operations = Operations(store: store, system: system, scheduler: scheduler, log: log)
    }

    public func start() async {
        await applySettings()
        await scheduler.reschedule()
    }

    func applySettings() async {
        do {
            let state = try await store.read()
            let settings = state.settings
            if !system.login.sync(wanted: settings.login) {
                try await store.update { $0.settings.login = false }
                log("login from the phone was turned off: macOS did not accept the login plugin")
            }
            if settings.wake, !system.settings.wakesForNetwork() {
                _ = system.settings.setWakesForNetwork(true)
            }
            system.settings.stayAwake(settings.awake)
            if !system.applyNet(state) { log("the firewall could not be set up") }
        } catch {
            log("could not read the settings: \(error)")
        }
    }

    public func statusReport() async throws -> JSONValue {
        operations.status(try await store.read())
    }

    public func respond(to request: HTTPRequest, from address: String) async -> HTTPResponse {
        switch (request.method, request.target) {
        case ("GET", "/v1/hello"):
            return await hello(from: address)
        case ("GET", _):
            return HTTPResponse(WireError.notFound)
        case ("POST", "/v1/pair"), ("POST", "/v1/call"):
            guard let body = request.body, let json = JSONValue(parsing: body), json.isObject else {
                return HTTPResponse(WireError.badRequest)
            }
            return request.target == "/v1/pair" ? await pair(json) : await call(json)
        case ("POST", _):
            return HTTPResponse(WireError.notFound)
        default:
            return HTTPResponse(WireError.unsupportedMethod)
        }
    }

    func hello(from address: String) async -> HTTPResponse {
        do {
            let state = try await store.read()
            let nonce = await nonces.issue(to: address)
            return HTTPResponse(status: 200, body: [
                "app": "curfew",
                "proto": .int(Limits.protocolVersion),
                "id": .string(state.id),
                "name": .string(system.host.hostName()),
                "nonce": .string(nonce),
            ])
        } catch {
            log("error in request: \(error)")
            return HTTPResponse(status: 500, body: ["error": "failed"])
        }
    }
}
