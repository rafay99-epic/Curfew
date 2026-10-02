import CurfewProtocol

extension Agent {
    func call(_ json: JSONValue) async -> HTTPResponse {
        guard let request = CallRequest(json) else { return HTTPResponse(WireError.badRequest) }
        let state: AgentState
        do {
            state = try await store.read()
        } catch {
            log("error in request: \(error)")
            return HTTPResponse(status: 500, body: ["error": "failed"])
        }
        let phone = state.phones[request.phone]
        guard let keyText = phone?.key ?? state.removed[request.phone]?.key, let key = Hex.decode(keyText) else {
            return HTTPResponse(WireError.unknownPhone)
        }
        guard request.isSigned(by: key) else { return HTTPResponse(WireError.badMAC) }
        guard await nonces.consume(request.snonce) else { return HTTPResponse(WireError.badNonce) }
        let result: JSONValue
        if phone == nil {
            result = OpError.unpaired.body
        } else if let body = JSONValue(parsing: request.payload) {
            result = await operations.run(body, phone: request.phone, state: state)
        } else {
            result = OpError.badRequest.body
        }
        return HTTPResponse(status: 200, body: request.response(key: key, payload: result.text))
    }
}
