import CoreFoundation
import SystemConfiguration

public struct ConsoleNotifier: Notifier {
    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    public func notify(_ text: String, user: String?) {
        let console = SCDynamicStoreCopyConsoleUser(nil, nil, nil) as String?
        guard let console, !console.isEmpty, console != "loginwindow", user == nil || user == console else { return }
        log("notice for \(console): \(text)")
        CFUserNotificationDisplayNotice(
            0, kCFUserNotificationCautionAlertLevel, nil, nil, nil,
            "Curfew" as CFString, text as CFString, "OK" as CFString
        )
    }
}
