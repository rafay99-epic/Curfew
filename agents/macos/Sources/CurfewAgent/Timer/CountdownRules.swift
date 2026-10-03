import Foundation

public enum CountdownStep: Sendable, Equatable {
    case fire
    case warn
}

extension AgentState.Countdown {
    public static let warningLead: Double = 60

    public func step(at now: Double) -> CountdownStep? {
        let left = deadline - now
        if left <= 0 { return .fire }
        return warn && !warned && left <= Self.warningLead ? .warn : nil
    }

    public var nextEvent: Double {
        warn && !warned ? deadline - Self.warningLead : deadline
    }

    public func remaining(at now: Double) -> Int {
        max(0, Int(deadline - now))
    }
}

extension AgentState.NetEntry {
    public func step(at now: Double) -> CountdownStep? {
        guard let deadline else { return nil }
        let left = deadline - now
        if left <= 0 { return .fire }
        return warn == true && warned != true && left <= AgentState.Countdown.warningLead ? .warn : nil
    }

    public var nextEvent: Double? {
        deadline.map { warn == true && warned != true ? $0 - AgentState.Countdown.warningLead : $0 }
    }
}

public enum Wall {
    public static func now() -> Double {
        Date().timeIntervalSince1970
    }
}

public enum HumanDuration {
    public static func text(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = Int((Double(seconds) / 60).rounded(.toNearestOrEven))
        let hours = minutes / 60
        let rest = minutes % 60
        return [(hours, "hour"), (rest, "minute")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
            .joined(separator: " ")
    }
}
