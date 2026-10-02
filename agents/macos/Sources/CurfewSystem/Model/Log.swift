import Foundation

public struct Log: Sendable {
    public let dry: Bool
    private let sink: @Sendable (String) -> Void

    public init(dry: Bool, sink: @escaping @Sendable (String) -> Void = Log.standardError) {
        self.dry = dry
        self.sink = sink
    }

    public func callAsFunction(_ message: String) {
        sink((dry ? "[dry-run] " : "") + message)
    }

    public static let standardError: @Sendable (String) -> Void = { line in
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
