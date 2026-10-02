public enum Op: String, Sendable, CaseIterable {
    case status
    case apps
    case poweroff
    case reboot
    case timerSet = "timer_set"
    case timerCancel = "timer_cancel"
    case lock
    case logout
    case login
    case netSet = "net_set"
    case netClear = "net_clear"
    case forget
}

public enum OpLookup: Sendable, Equatable {
    case known(Op)
    case unknown
    case malformed

    public init(_ value: JSONValue?) {
        switch value {
        case .string(let name): self = Op(rawValue: name).map(OpLookup.known) ?? .unknown
        case .array, .object: self = .malformed
        default: self = .unknown
        }
    }
}
