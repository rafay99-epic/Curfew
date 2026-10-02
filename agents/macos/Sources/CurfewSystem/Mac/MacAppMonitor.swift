import Foundation

public struct MacAppMonitor: AppMonitor {
    public init() {}

    public func openApps(of user: SystemUser) -> [OpenApp] {
        let processes = ProcessTable.snapshot(uid: user.uid)
        return AppSelection.select(processes, now: Int(time(nil))) { process in
            guard let bundle = AppBundle.bundlePath(ofMainExecutable: process.path),
                  !AppBundle.runsInBackground(bundle)
            else { return nil }
            return AppBundle.displayName(of: bundle)
        }
    }
}
