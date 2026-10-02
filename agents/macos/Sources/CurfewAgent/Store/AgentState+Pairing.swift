import CurfewControl
import CurfewProtocol

extension AgentState {
    public var orderedPhones: [(id: String, phone: Phone)] {
        phones
            .map { (id: $0.key, phone: $0.value) }
            .sorted { ($0.phone.added, $0.id) < ($1.phone.added, $1.id) }
    }

    public mutating func offerPairing(code: String, now: Double) {
        pairing = Pairing(code: code, expires: now + PairingCode.lifetime)
    }

    public mutating func withdrawPairing(code: String) {
        if pairing?.code == code {
            pairing = nil
        }
    }

    public func pairingProgress(code: String, since started: Double, now: Double) -> PairingProgress {
        let ours = pairing?.code == code
        if let last = lastPaired, last.when >= started, !ours {
            return .paired(phone: last.name)
        }
        guard let pairing, ours else {
            return now > started + PairingCode.lifetime ? .expired : .cancelled
        }
        guard now <= pairing.expires else { return .expired }
        return .pending(expiresIn: Int((pairing.expires - now).rounded(.up)))
    }

    @discardableResult
    public mutating func removePhone(_ id: String, now: Int) -> Phone? {
        guard let phone = phones.removeValue(forKey: id) else { return nil }
        removed[id] = RemovedPhone(key: phone.key, name: phone.name, when: now)
        let stale = removed.sorted { $0.value.when < $1.value.when }.dropLast(Limits.removedPhonesKept)
        stale.forEach { removed.removeValue(forKey: $0.key) }
        return phone
    }
}
