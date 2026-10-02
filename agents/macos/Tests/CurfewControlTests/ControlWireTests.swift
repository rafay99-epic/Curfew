import CurfewControl
import CurfewProtocol
import Testing

@Suite struct ControlWireTests {
    @Test(arguments: [
        ControlRequest.status, .pairStart, .pairStatus(code: "ABCD"), .pairCancel(code: "ABCD"), .unpair(phone: "0011223344556677"),
    ])
    func requestsRoundTrip(_ request: ControlRequest) throws {
        let line = request.json.text
        #expect(!line.contains("\n"))
        #expect(ControlRequest(try #require(JSONValue(parsing: line))) == request)
    }

    @Test func malformedRequestsAreRejected() {
        #expect(ControlRequest(["cmd": "reboot"]) == nil)
        #expect(ControlRequest(["cmd": "pair_status"]) == nil)
        #expect(ControlRequest(["cmd": "unpair", "phone": 7]) == nil)
        #expect(ControlRequest([1, 2]) == nil)
    }

    @Test func statusRoundTrip() throws {
        let offer = PairingOffer(address: "192.168.1.24:787", agent: "0b825f00961665a4", code: "K7PMQ2XR9DHA4FWE", expiresIn: 102)
        let status = ControlStatus(
            name: "MacBook Pro", version: "2.0.0", dry: false,
            phones: [ControlPhone(id: "a1", name: "Rafay's Pixel", pairedAt: 1_700_000_000)], pairing: offer
        )
        let parsed = try #require(JSONValue(parsing: status.json.text))
        #expect(parsed["running"] == true)
        #expect(ControlStatus(parsed) == status)
        #expect(ControlStatus(["ok": false, "error": "failed"]) == nil)
    }

    @Test func offerBuildsTheSameLinkAsTheCLI() {
        let offer = PairingOffer(address: "192.168.1.24:8787", agent: "0b825f00961665a4", code: "K7PMQ2XR9DHA4FWE", expiresIn: 120)
        #expect(offer.uri == "curfew://pair?a=192.168.1.24:8787&i=0b825f00961665a4&c=K7PMQ2XR9DHA4FWE")
        #expect(offer.codeLines == ["K7PM-Q2XR", "9DHA-4FWE"])
    }

    @Test(arguments: [PairingProgress.pending(expiresIn: 42), .paired(phone: "Work phone"), .expired, .cancelled])
    func progressRoundTrip(_ progress: PairingProgress) {
        #expect(PairingProgress(progress.json) == progress)
    }

    @Test func errorsAreReadBack() {
        #expect(ControlError(reply: ControlError.noPhone.json) == .noPhone)
        #expect(ControlError(reply: ["ok": false, "error": "something new"]) == .failed)
        #expect(ControlError(reply: ["ok": true]) == nil)
    }
}
