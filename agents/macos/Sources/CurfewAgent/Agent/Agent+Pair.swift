import CurfewProtocol
import CurfewSystem

extension Agent {
    private enum PairOutcome: Sendable {
        case paired(name: String, body: JSONValue)
        case refused(WireError)
    }

    func pair(_ json: JSONValue) async -> HTTPResponse {
        guard let request = PairRequest(json) else { return HTTPResponse(WireError.badRequest) }
        guard await nonces.consume(request.snonce) else { return HTTPResponse(WireError.badNonce) }
        let now = Wall.now()
        let hostName = system.host.hostName()
        do {
            let outcome = try await store.update { state -> PairOutcome in
                guard let pairing = state.pairing, pairing.expires >= now else {
                    state.pairing = nil
                    return .refused(.noPairing)
                }
                guard request.isSigned(byCode: pairing.code) else {
                    let fails = pairing.fails + 1
                    state.pairing = fails >= PairingCode.maxFailures ? nil : AgentState.Pairing(code: pairing.code, expires: pairing.expires, fails: fails)
                    return .refused(.badCode)
                }
                guard let requested = PhoneName.requested(in: request.payload) else { return .refused(.badRequest) }
                let name = PhoneName.unique(PhoneName.sanitized(requested), taken: Set(state.phones.values.map(\.name)))
                let phone = Token.random(bytes: 8)
                let key = request.key(code: pairing.code, phone: phone)
                state.phones[phone] = AgentState.Phone(name: name, key: Hex.encode(key), added: Int(now))
                state.pairing = nil
                state.lastPaired = AgentState.LastPaired(name: name, when: now)
                let answer: JSONValue = [
                    "ok": true,
                    "id": .string(state.id),
                    "name": .string(hostName),
                    "phone_name": .string(name),
                ]
                return .paired(name: name, body: request.response(phone: phone, key: key, payload: answer.text))
            }
            switch outcome {
            case .paired(let name, let body):
                log("paired phone \"\(name)\"")
                return HTTPResponse(status: 200, body: body)
            case .refused(let error):
                return HTTPResponse(error)
            }
        } catch {
            log("error in request: \(error)")
            return HTTPResponse(status: 500, body: ["error": "failed"])
        }
    }
}
