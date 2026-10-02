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
        await scheduler.reschedule()
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
