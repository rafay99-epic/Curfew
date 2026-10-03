import CurfewProtocol
import Foundation
import Network

struct HTTPExchange: Sendable {
    let connection: NWConnection
    let address: String
    let handler: HTTPServer.Handler

    func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withTaskCancellationHandler {
                    await exchange()
                } onCancel: {
                    connection.cancel()
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(Limits.requestTimeoutSeconds))
            }
            await group.next()
            group.cancelAll()
        }
        connection.cancel()
    }

    private func exchange() async {
        guard let outcome = await readRequest() else { return }
        let reply: HTTPResponse
        switch outcome {
        case .success(let request): reply = await handler(request, address)
        case .failure(let error): reply = HTTPResponse(error)
        }
        await send(reply.bytes)
    }

    private func readRequest() async -> Result<HTTPRequest, WireError>? {
        var buffer: [UInt8] = []
        var head: RequestHead?
        var body: [UInt8] = []
        while true {
            if head == nil, let parts = RequestHead.split(buffer) {
                guard let parsed = RequestHead.parse(parts.head) else { return .failure(.badRequest) }
                head = parsed
                body = Array(parts.rest)
                buffer = []
            }
            if let head {
                guard let expected = head.expectedBody else {
                    return .success(HTTPRequest(method: head.method, target: head.target, body: nil))
                }
                if body.count >= expected {
                    return .success(HTTPRequest(method: head.method, target: head.target, body: Array(body.prefix(expected))))
                }
            } else if buffer.count > Limits.maxHead {
                return nil
            }
            guard let chunk = await receive() else { return nil }
            if head == nil { buffer += chunk.data } else { body += chunk.data }
            if chunk.complete && chunk.data.isEmpty { return nil }
        }
    }

    private func receive() async -> (data: [UInt8], complete: Bool)? {
        await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, complete, error in
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: (data.map { [UInt8]($0) } ?? [], complete))
                }
            }
        }
    }

    private func send(_ bytes: [UInt8]) async {
        await withCheckedContinuation { continuation in
            connection.send(content: Data(bytes), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }
}
