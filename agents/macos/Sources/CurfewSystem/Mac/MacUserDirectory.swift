import Darwin.membership
import Foundation
import OpenDirectory

public struct MacUserDirectory: UserDirectory {
    static let adminGroup: gid_t = 80
    static let firstHumanUID: uid_t = 501
    static let hiddenAttribute = "dsAttrTypeNative:IsHidden"

    public init() {}

    public func humanUsers() -> [SystemUser] {
        records()
            .compactMap(Self.user)
            .sorted { $0.uid < $1.uid }
    }

    private func records() -> [ODRecord] {
        let attributes = [
            kODAttributeTypeRecordName, kODAttributeTypeUniqueID, kODAttributeTypeUserShell,
            kODAttributeTypeFullName, Self.hiddenAttribute,
        ]
        do {
            let node = try ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeLocalNodes))
            let query = try ODQuery(
                node: node, forRecordTypes: kODRecordTypeUsers, attribute: nil,
                matchType: ODMatchType(kODMatchAny), queryValues: nil,
                returnAttributes: attributes, maximumResults: 0
            )
            return try query.resultsAllowingPartial(false).compactMap { $0 as? ODRecord }
        } catch {
            return []
        }
    }

    private static func user(_ record: ODRecord) -> SystemUser? {
        func first(_ attribute: String) -> String? {
            (try? record.values(forAttribute: attribute))?.first as? String
        }
        guard let name = first(kODAttributeTypeRecordName),
              let uidText = first(kODAttributeTypeUniqueID), let uid = uid_t(uidText)
        else { return nil }
        let shell = first(kODAttributeTypeUserShell) ?? ""
        guard UserRules.isHuman(name: name, uid: uid, shell: shell, hidden: first(hiddenAttribute)) else { return nil }
        return SystemUser(name: name, full: first(kODAttributeTypeFullName) ?? name, admin: isAdmin(uid), uid: uid)
    }

    public static func isAdmin(_ uid: uid_t) -> Bool {
        var user: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var group: uuid_t = user
        var member: Int32 = 0
        guard mbr_uid_to_uuid(uid, &user) == 0, mbr_gid_to_uuid(adminGroup, &group) == 0 else { return false }
        return mbr_check_membership(&user, &group, &member) == 0 && member == 1
    }
}

enum UserRules {
    static func isHuman(name: String, uid: uid_t, shell: String, hidden: String?) -> Bool {
        uid >= MacUserDirectory.firstHumanUID
            && uid < 60000
            && !name.hasPrefix("_")
            && !shell.hasSuffix("nologin")
            && !shell.hasSuffix("false")
            && !["1", "yes", "true"].contains(hidden?.lowercased() ?? "")
    }
}
