import CurfewLogin
import Foundation
import Testing

@Suite struct LoginStoreTests {
    let dir = NSTemporaryDirectory() + "cf-login-" + UUID().uuidString

    func mode(_ path: String) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.posixPermissions] as? Int
    }

    @Test func namesThatCouldEscapeAreRefused() {
        for bad in ["", ".", "..", "../x", "a/b", "-x", ".hidden", "a b", String(repeating: "a", count: 300)] {
            #expect(curfew_valid_name(bad) == 0, "\(bad)")
        }
        for good in ["rafay", "ali.khan", "user_2", "Guest-1"] {
            #expect(curfew_valid_name(good) == 1, "\(good)")
        }
        #expect(curfew_approve(dir, "../escape", 100) == 0)
        #expect(!FileManager.default.fileExists(atPath: dir))
    }

    @Test func approvalWorksOnceAndOnlyBeforeItsDeadline() {
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        #expect(mode(dir + "/approved") == 0o700)
        #expect(mode(dir + "/approved/ali") == 0o600)
        #expect(curfew_take_approval(dir, "ali", 900) == 1)
        #expect(curfew_take_approval(dir, "ali", 900) == 0)
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        #expect(curfew_take_approval(dir, "ali", 1001) == 0)
        #expect(curfew_approve(dir, "ali", 5000) == 1)
        #expect(curfew_take_approval(dir, "ali", 1000) == 0)
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        curfew_revoke(dir, "ali")
        #expect(curfew_take_approval(dir, "ali", 900) == 0)
    }

    @Test func passwordIsFilledOnlyWhenApprovedAndNothingWasTyped() {
        defer { try? FileManager.default.removeItem(atPath: dir) }
        var buffer = [CChar](repeating: 0, count: 64)
        #expect(curfew_knows(dir, "ali") == 0)
        #expect(curfew_fill_login(dir, "ali", 0, 900, &buffer, buffer.count) == -1)
        #expect(curfew_should_remember("ali", 7) == 1)
        #expect(curfew_should_remember("ali", 0) == 0)
        #expect(curfew_should_remember("../x", 7) == 0)
        #expect(curfew_remember(dir, "ali", "hunter2", 7) == 1)
        #expect(curfew_knows(dir, "ali") == 1)
        #expect(mode(dir + "/secret/ali") == 0o600)
        #expect(curfew_fill_login(dir, "ali", 0, 900, &buffer, buffer.count) == -1)
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        #expect(curfew_fill_login(dir, "ali", 3, 900, &buffer, buffer.count) == -1)
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        #expect(curfew_fill_login(dir, "ali", -1, 900, &buffer, buffer.count) == 7)
        #expect(String(cString: buffer) == "hunter2")
        #expect(curfew_fill_login(dir, "ali", -1, 900, &buffer, buffer.count) == -1)
    }

    @Test func unlockFollowsTheApprovalOfTheConsoleUser() {
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(curfew_allow_unlock(dir, "ali", 900) == 0)
        #expect(curfew_approve(dir, "ali", 1000) == 1)
        #expect(curfew_allow_unlock(dir, "rafay", 900) == 0)
        #expect(curfew_allow_unlock(dir, "ali", 900) == 1)
        #expect(curfew_allow_unlock(dir, "ali", 900) == 0)
    }

    @Test func oversizedSecretsAreRefused() {
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let long = String(repeating: "x", count: Int(CURFEW_SECRET_MAX) + 1)
        #expect(curfew_remember(dir, "ali", long, long.utf8.count) == 0)
        #expect(curfew_knows(dir, "ali") == 0)
    }
}
