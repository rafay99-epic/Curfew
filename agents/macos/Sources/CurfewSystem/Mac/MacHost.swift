import Foundation
import SystemConfiguration

public struct MacHost: HostInfo {
    public init() {}

    public func hostName() -> String {
        if let name = SCDynamicStoreCopyComputerName(nil, nil) as String?, !name.isEmpty {
            return name
        }
        var buffer = [CChar](repeating: 0, count: 256)
        guard gethostname(&buffer, buffer.count) == 0 else { return "Mac" }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    public func osName() -> String {
        let path = "/System/Library/CoreServices/SystemVersion.plist"
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = plist["ProductVersion"] as? String
        else { return "macOS" }
        return "macOS \(version)"
    }

    public func wakeAddress() -> String? {
        LocalNetwork.lanAddress().flatMap(LocalNetwork.hardwareAddress)
    }
}
