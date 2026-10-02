import CurfewControl
import CurfewProtocol
import Dispatch

enum ControlClientError: Error, Equatable {
    case malformed
}

actor ControlClient {
    let path: String

    init(path: String) {
        self.path = path
    }

    func status() async throws -> ControlStatus {
        guard let status = ControlStatus(try await send(.status)) else { throw ControlClientError.malformed }
        return status
    }

    func startPairing() async throws -> PairingOffer {
        guard let offer = PairingOffer(try await send(.pairStart)) else { throw ControlClientError.malformed }
        return offer
    }

    func progress(of code: String) async throws -> PairingProgress {
        guard let progress = PairingProgress(try await send(.pairStatus(code: code))) else { throw ControlClientError.malformed }
        return progress
    }

    func cancelPairing(_ code: String) async throws {
        _ = try await send(.pairCancel(code: code))
    }

    func unpair(_ phone: String) async throws {
        _ = try await send(.unpair(phone: phone))
    }

    private func send(_ request: ControlRequest) async throws -> JSONValue {
        let path = self.path
        let result = await withCheckedContinuation { (done: CheckedContinuation<Result<JSONValue, ControlSocketError>, Never>) in
            DispatchQueue.global().async {
                done.resume(returning: Result { () throws(ControlSocketError) in try ControlSocket.exchange(path, request.json) })
            }
        }
        let reply = try result.get()
        if let error = ControlError(reply: reply) { throw error }
        return reply
    }
}
