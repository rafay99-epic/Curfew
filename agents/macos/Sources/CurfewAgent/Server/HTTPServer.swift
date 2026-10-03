import CurfewProtocol
import Foundation
import Network
import os

public enum HTTPServerError: Error, Sendable {
    case badAddress(String)
    case failed(String)
}

public final class HTTPServer: Sendable {
    public typealias Handler = @Sendable (HTTPRequest, String) async -> HTTPResponse

    public struct Advertisement: Sendable {
        public let name: String
        public let agentID: String

        public init(name: String, agentID: String) {
            self.name = name
            self.agentID = agentID
        }
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "curfew.http")
    private let limiter = ConnectionLimiter()
    private let handler: Handler

    public init(host: String, port: UInt16, advertisement: Advertisement? = nil, handler: @escaping Handler) throws {
        guard let address = IPv4Address(host), let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw HTTPServerError.badAddress(host)
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(address), port: endpointPort)
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        listener = try NWListener(using: parameters)
        if let advertisement {
            listener.service = NWListener.Service(
                name: advertisement.name, type: "_curfew._tcp", domain: nil,
                txtRecord: NWTXTRecord(["id": advertisement.agentID])
            )
        }
        self.handler = handler
    }

    public func start() async throws -> UInt16 {
        let once = OSAllocatedUnfairLock<CheckedContinuation<UInt16, any Error>?>(initialState: nil)
        let listener = self.listener
        return try await withCheckedThrowingContinuation { continuation in
            once.withLock { $0 = continuation }
            listener.stateUpdateHandler = { [weak listener] state in
                let pending: CheckedContinuation<UInt16, any Error>? = switch state {
                case .ready, .failed, .cancelled: once.withLock { taken in
                    defer { taken = nil }
                    return taken
                }
                default: nil
                }
                switch state {
                case .ready: pending?.resume(returning: listener?.port?.rawValue ?? 0)
                case .failed(let error): pending?.resume(throwing: HTTPServerError.failed("\(error)"))
                case .cancelled: pending?.resume(throwing: HTTPServerError.failed("cancelled"))
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        }
    }

    public func stop() {
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        let address = Self.address(of: connection.endpoint)
        guard limiter.acquire(address) else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        let limiter = self.limiter
        let handler = self.handler
        Task {
            await HTTPExchange(connection: connection, address: address, handler: handler).run()
            limiter.release(address)
        }
    }

    private static func address(of endpoint: NWEndpoint) -> String {
        guard case .hostPort(let host, _) = endpoint else { return "\(endpoint)" }
        switch host {
        case .ipv4(let address): return address.rawValue.map(String.init).joined(separator: ".")
        case .ipv6(let address): return "\(address)"
        case .name(let name, _): return name
        @unknown default: return "\(host)"
        }
    }
}
