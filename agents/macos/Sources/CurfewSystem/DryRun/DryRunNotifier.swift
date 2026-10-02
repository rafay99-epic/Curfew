public struct DryRunNotifier: Notifier {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func notify(_ text: String) {
        log("would notify: \(text)")
    }
}
