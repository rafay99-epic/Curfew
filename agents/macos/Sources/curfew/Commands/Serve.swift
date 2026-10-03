import CurfewAgent
import CurfewSystem
import Dispatch
import Foundation
import os

enum Serve {
    struct Options: Sendable {
        var port: UInt16
        var bind = "0.0.0.0"
        var bonjour: Bool

        init(_ arguments: [String], settings: Settings) throws {
            port = settings.port
            bonjour = !settings.dry
            var rest = arguments[...]
            while let option = rest.popFirst() {
                switch option {
                case "--port":
                    guard let value = rest.popFirst().flatMap(UInt16.init) else { throw ServeError.usage }
                    port = value
                case "--bind":
                    guard let value = rest.popFirst() else { throw ServeError.usage }
                    bind = value
                case "--bonjour":
                    bonjour = true
                default:
                    throw ServeError.usage
                }
            }
        }
    }

    enum ServeError: Error, CustomStringConvertible {
        case usage

        var description: String { "usage: curfew serve [--dry-run] [--port N] [--bind ADDRESS] [--bonjour]" }
    }

    static func run(_ settings: Settings, options arguments: [String]) async throws -> Int32 {
        let options = try Options(arguments, settings: settings)
        let log = settings.log
        let system = settings.system(log: log)
        let agent = Agent(store: settings.store, system: system, log: log)
        let id = try await agent.store.read().id
        let advertisement = options.bonjour ? HTTPServer.Advertisement(name: system.host.hostName(), agentID: id) : nil
        let server = try HTTPServer(host: options.bind, port: options.port, advertisement: advertisement) { request, address in
            await agent.respond(to: request, from: address)
        }
        let port = try await server.start()
        log("Curfew agent \(id) listening on \(options.bind) port \(port)")
        let control = startControl(settings, system: system, port: port, log: log)
        await agent.start()
        await waitForTermination()
        control?.stop()
        server.stop()
        log("stopped")
        return 0
    }

    private static func startControl(_ settings: Settings, system: SystemServices, port: UInt16, log: Log) -> ControlServer? {
        let service = ControlService(store: settings.store, system: system, port: port, dry: settings.dry, log: log)
        do {
            let server = try ControlServer(
                path: settings.controlSocket, access: settings.dry ? .owner : .admins,
                policy: .system(dry: settings.dry)
            ) { line in
                await service.respond(to: line)
            }
            server.start()
            log("control socket at \(settings.controlSocket)")
            return server
        } catch {
            log("no control socket: \(error)")
            return nil
        }
    }

    private static func waitForTermination() async {
        let pending = OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>(initialState: nil)
        var sources: [any DispatchSourceSignal] = []
        await withCheckedContinuation { continuation in
            pending.withLock { $0 = continuation }
            for signalNumber in [SIGINT, SIGTERM] {
                signal(signalNumber, SIG_IGN)
                let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
                source.setEventHandler {
                    let waiting = pending.withLock { taken in
                        defer { taken = nil }
                        return taken
                    }
                    waiting?.resume()
                }
                source.resume()
                sources.append(source)
            }
        }
        sources.forEach { $0.cancel() }
    }
}
