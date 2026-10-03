import Foundation
import Security

public protocol AuthorizationDatabase: Sendable {
    func read(_ right: String) -> [String: Any]?
    func write(_ right: String, _ definition: [String: Any]) -> Bool
    func remove(_ right: String) -> Bool
    func loads(_ right: String) -> Bool
}

public struct SecurityAuthorizationDatabase: AuthorizationDatabase {
    static let tool = "/usr/bin/security"

    public init() {}

    public func read(_ right: String) -> [String: Any]? {
        let result = Command.run([Self.tool, "authorizationdb", "read", right])
        guard result.status == 0, let start = result.output.range(of: "<?xml") else { return nil }
        let data = Data(result.output[start.lowerBound...].utf8)
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    public func write(_ right: String, _ definition: [String: Any]) -> Bool {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: definition, format: .xml, options: 0) else { return false }
        return Command.run([Self.tool, "authorizationdb", "write", right], input: String(decoding: data, as: UTF8.self)).status == 0
    }

    public func remove(_ right: String) -> Bool {
        Command.run([Self.tool, "authorizationdb", "remove", right]).status == 0
    }

    public func loads(_ right: String) -> Bool {
        var reference: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &reference) == errAuthorizationSuccess, let reference else { return false }
        defer { AuthorizationFree(reference, [.destroyRights]) }
        return right.withCString { name in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                return AuthorizationCopyRights(reference, &rights, nil, [.extendRights], nil) == errAuthorizationSuccess
            }
        }
    }
}
