@testable import curfew
import CurfewControl
import Foundation
import os
import Testing

final class CommandLog: Sendable {
    private let lines = OSAllocatedUnfairLock(initialState: [[String]]())
    let firewall: String

    init(firewall: String = "Firewall is disabled. (State = 0)") {
        self.firewall = firewall
    }

    var runner: CommandRunner {
        CommandRunner { [lines, firewall] argv in
            lines.withLock { $0.append(argv) }
            return (0, argv.last == "--getglobalstate" ? firewall : "")
        }
    }

    var commands: [[String]] { lines.withLock { $0 } }
}

@Suite struct InstallerTests {
    let root = "/tmp/cf-root-" + UUID().uuidString.prefix(8)
    var layout: Layout { Layout(root: root) }

    func fakeBinary() throws -> String {
        let path = root + "/source/curfew"
        try FileManager.default.createDirectory(atPath: root + "/source", withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: Data("#!/bin/sh\n".utf8))
        return path
    }

    func mode(_ path: String) throws -> Int? {
        try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
    }

    @Test func installLaysOutTheFilesAndIsRepeatable() throws {
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try fakeBinary()
        let installer = Installer(layout: layout, runner: nil)
        #expect(try installer.install(from: source).isEmpty)
        #expect(try installer.install(from: source).isEmpty)
        #expect(FileManager.default.contents(atPath: layout.binary) == Data("#!/bin/sh\n".utf8))
        #expect(try mode(layout.binary) == 0o755)
        #expect(try mode(layout.launchDaemon) == 0o644)
        #expect(try mode(layout.commandDirectory) == 0o755)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: layout.command) == layout.binary)
        let data = try #require(FileManager.default.contents(atPath: layout.launchDaemon))
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["Label"] as? String == "com.rafay99.curfew")
        #expect(plist["ProgramArguments"] as? [String] == [layout.binary, "serve"])
        #expect(plist["RunAtLoad"] as? Bool == true && plist["KeepAlive"] as? Bool == true)
        #expect(plist["ProcessType"] == nil)
    }

    @Test func anotherCommandAtTheLinkIsLeftAlone() throws {
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try fakeBinary()
        try FileManager.default.createDirectory(atPath: layout.commandDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: layout.command, contents: Data("other".utf8))
        let notes = try Installer(layout: layout, runner: nil).install(from: source)
        #expect(notes == ["Left \(layout.command) alone: another file is there."])
        try Installer(layout: layout, runner: nil).uninstall(purge: true)
        #expect(FileManager.default.contents(atPath: layout.command) == Data("other".utf8))
    }

    @Test func uninstallKeepsThePhonesUnlessPurged() throws {
        defer { try? FileManager.default.removeItem(atPath: root) }
        let installer = Installer(layout: layout, runner: nil)
        _ = try installer.install(from: try fakeBinary())
        let state = layout.supportDirectory + "/state.json"
        FileManager.default.createFile(atPath: state, contents: Data("{}".utf8))
        try installer.uninstall(purge: false)
        for gone in [layout.binary, layout.launchDaemon, layout.command, layout.binDirectory] {
            #expect(!FileManager.default.fileExists(atPath: gone), "\(gone)")
        }
        #expect(FileManager.default.fileExists(atPath: state))
        try installer.uninstall(purge: true)
        #expect(!FileManager.default.fileExists(atPath: layout.supportDirectory))
    }

    @Test func serviceCommandsInOrder() throws {
        defer { try? FileManager.default.removeItem(atPath: root) }
        let log = CommandLog(firewall: "Firewall is enabled. (State = 1)")
        let installer = Installer(layout: layout, runner: log.runner)
        _ = try installer.install(from: try fakeBinary())
        try installer.restart()
        try installer.uninstall(purge: false)
        let fw = Installer.firewall
        #expect(log.commands == [
            ["/bin/launchctl", "bootout", "system/com.rafay99.curfew"],
            ["/bin/launchctl", "bootstrap", "system", layout.launchDaemon],
            [fw, "--getglobalstate"],
            [fw, "--add", layout.binary],
            [fw, "--unblockapp", layout.binary],
            ["/bin/launchctl", "bootstrap", "system", layout.launchDaemon],
            ["/bin/launchctl", "kickstart", "-k", "system/com.rafay99.curfew"],
            ["/bin/launchctl", "bootout", "system/com.rafay99.curfew"],
            [fw, "--remove", layout.binary],
        ])
    }

    @Test func firewallOffMeansNoFirewallChanges() throws {
        defer { try? FileManager.default.removeItem(atPath: root) }
        let log = CommandLog()
        _ = try Installer(layout: layout, runner: log.runner).install(from: try fakeBinary())
        #expect(log.commands.last == [Installer.firewall, "--getglobalstate"])
    }

    @Test func aTestRootNeverTouchesServices() throws {
        let settings = Settings(argv: ["install"], environment: ["CURFEW_ROOT": root])
        #expect(settings.layout.binary == root + "/Library/Application Support/Curfew/bin/curfew")
        #expect(try Setup.installer(settings, command: "install", options: []).runner == nil)
        #expect(try Setup.installer(settings, command: "uninstall", options: ["--purge"]).runner == nil)
        #expect(throws: Setup.SetupError.self) { try Setup.installer(settings, command: "install", options: ["--purge"]) }
        let live = Settings(argv: ["install"], environment: [:])
        #expect(try Setup.installer(live, command: "install", options: ["--files-only"]).runner == nil)
        #expect(Layout.live.controlSocket == "/var/run/curfew.sock")
        #expect(Layout.live.launchDaemon == "/Library/LaunchDaemons/com.rafay99.curfew.plist")
        #expect(Layout.live.command == "/usr/local/bin/curfew")
    }
}
