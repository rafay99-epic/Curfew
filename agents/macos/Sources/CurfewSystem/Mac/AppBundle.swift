import Foundation

enum AppBundle {
    static func bundlePath(ofMainExecutable path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        let count = parts.count
        guard count >= 5,
              parts[count - 2] == "MacOS",
              parts[count - 3] == "Contents",
              parts[count - 4].hasSuffix(".app"),
              !parts[count - 4].contains("Helper"),
              !path.contains("/XPCServices/"),
              !path.hasPrefix("/System/Library/"),
              !path.hasPrefix("/Library/")
        else { return nil }
        return parts[..<(count - 3)].joined(separator: "/")
    }

    static func displayName(of bundlePath: String) -> String {
        let folder = bundlePath.split(separator: "/").last.map(String.init) ?? bundlePath
        return folder.hasSuffix(".app") ? String(folder.dropLast(4)) : folder
    }

    static func runsInBackground(_ bundlePath: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: bundlePath + "/Contents/Info.plist"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return false }
        return isSet(plist["LSUIElement"]) || isSet(plist["LSBackgroundOnly"])
    }

    private static func isSet(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool: flag
        case let number as NSNumber: number.intValue != 0
        case let text as String: ["1", "yes", "true"].contains(text.lowercased())
        default: false
        }
    }
}
