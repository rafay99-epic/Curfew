import AppKit

enum PrivilegedAction: String, Sendable, CaseIterable {
    case install
    case uninstall
    case restart
}

enum PrivilegedError: Error, Equatable {
    case cancelled
    case missingTool
    case failed(String)
}

protocol PrivilegedRunning: Sendable {
    @MainActor func run(_ action: PrivilegedAction) async throws(PrivilegedError)
}

enum AdminScript {
    static func source(tool: String, action: PrivilegedAction) -> String {
        "do shell script " + appleScriptString(shellQuoted(tool) + " " + action.rawValue) + " with administrator privileges"
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

struct AppleScriptRunner: PrivilegedRunning {
    static let userCancelled = -128

    let tool: URL?

    static var bundledTool: URL? {
        guard let tool = Bundle.main.resourceURL?.appending(path: "curfew"),
              FileManager.default.isExecutableFile(atPath: tool.path)
        else { return nil }
        return tool
    }

    @MainActor func run(_ action: PrivilegedAction) async throws(PrivilegedError) {
        guard let tool else { throw .missingTool }
        guard let script = NSAppleScript(source: AdminScript.source(tool: tool.path, action: action)) else {
            throw .failed("The script could not be prepared.")
        }
        var failure: NSDictionary?
        script.executeAndReturnError(&failure)
        guard let failure else { return }
        if failure[NSAppleScript.errorNumber] as? Int == Self.userCancelled { throw .cancelled }
        throw .failed(failure[NSAppleScript.errorMessage] as? String ?? "Unknown error.")
    }
}
