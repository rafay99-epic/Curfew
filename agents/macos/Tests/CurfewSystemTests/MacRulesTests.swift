@testable import CurfewSystem
import Foundation
import Testing

@Suite struct SessionStateTests {
    @Test func consoleFlagsMapToProtocolStates() {
        #expect(ConsoleSessions.state(onConsole: true, loginDone: true, screenLocked: false) == .active)
        #expect(ConsoleSessions.state(onConsole: true, loginDone: true, screenLocked: true) == .locked)
        #expect(ConsoleSessions.state(onConsole: false, loginDone: true, screenLocked: false) == .loggedIn)
        #expect(ConsoleSessions.state(onConsole: true, loginDone: false, screenLocked: false) == .loggedIn)
    }

    @Test func missingLockKeyMeansUnlockedAndBestStateWins() {
        let states = ConsoleSessions.states([
            ["kCGSSessionUserNameKey": "kid", "kCGSSessionOnConsoleKey": false, "kCGSessionLoginDoneKey": true],
            ["kCGSSessionUserNameKey": "kid", "kCGSSessionOnConsoleKey": true, "kCGSessionLoginDoneKey": true],
            ["kCGSSessionUserNameKey": "dad", "kCGSSessionOnConsoleKey": true, "kCGSessionLoginDoneKey": true, "CGSSessionScreenIsLocked": true],
        ])
        #expect(states == ["kid": .active, "dad": .locked])
    }
}

@Suite struct UserRulesTests {
    @Test func onlyVisibleHumanAccounts() {
        #expect(UserRules.isHuman(name: "kid", uid: 502, shell: "/bin/zsh", hidden: nil))
        #expect(!UserRules.isHuman(name: "daemon", uid: 1, shell: "/usr/bin/false", hidden: nil))
        #expect(!UserRules.isHuman(name: "_mbsetupuser", uid: 248, shell: "/bin/bash", hidden: nil))
        #expect(!UserRules.isHuman(name: "svc", uid: 600, shell: "/usr/bin/false", hidden: nil))
        #expect(!UserRules.isHuman(name: "svc", uid: 600, shell: "/sbin/nologin", hidden: nil))
        #expect(!UserRules.isHuman(name: "ghost", uid: 600, shell: "/bin/zsh", hidden: "1"))
    }
}

@Suite struct AppRulesTests {
    @Test func onlyMainExecutablesOfAppBundles() {
        #expect(AppBundle.bundlePath(ofMainExecutable: "/Applications/Minecraft.app/Contents/MacOS/launcher") == "/Applications/Minecraft.app")
        #expect(AppBundle.bundlePath(ofMainExecutable: "/Users/kid/Applications/Game.app/Contents/MacOS/Game") == "/Users/kid/Applications/Game.app")
        #expect(AppBundle.bundlePath(ofMainExecutable: "/Applications/Brave Browser.app/Contents/Frameworks/Brave Helper (Renderer).app/Contents/MacOS/Brave Helper (Renderer)") == nil)
        #expect(AppBundle.bundlePath(ofMainExecutable: "/Applications/X.app/Contents/XPCServices/Y.xpc/Contents/MacOS/Y") == nil)
        #expect(AppBundle.bundlePath(ofMainExecutable: "/Applications/X.app/Contents/Resources/tool") == nil)
        #expect(AppBundle.bundlePath(ofMainExecutable: "/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock") == nil)
        #expect(AppBundle.bundlePath(ofMainExecutable: "/usr/bin/vim") == nil)
        #expect(AppBundle.displayName(of: "/Applications/Brave Browser.app") == "Brave Browser")
    }

    @Test func friendlyCommandNames() {
        #expect(CommandName.friendly(["java", "-Xmx2G", "-jar", "/Users/k/TLauncher-2.9.jar"]).name == "TLauncher-2.9.jar (Java)")
        #expect(CommandName.friendly(["/usr/bin/java", "-cp", "a.jar:b.jar", "net.minecraft.client.main.Main", "--x"]).name == "Main (Java)")
        #expect(CommandName.friendly(["python3", "-u", "game.py"]).name == "game.py (Python)")
        #expect(CommandName.friendly(["python3.12", "-c", "print(1)"]).name == "Python")
        #expect(CommandName.friendly(["env", "FOO=1", "nohup", "vim", "notes.txt"]).name == "vim")
        #expect(CommandName.friendly(["/opt/x/weird-game", "--fast"]) == ("weird-game", "/opt/x/weird-game --fast"))
        let long = CommandName.friendly(["tool", String(repeating: "x", count: 200)]).detail
        #expect(long.unicodeScalars.count == 140 && long.hasSuffix("…"))
    }

    @Test func selectionKeepsTopTerminalProgramsAndDesktopApps() {
        func record(_ pid: Int32, _ ppid: Int32, start: Int, tty: Bool, comm: String, path: String = "", args: [String] = []) -> ProcessRecord {
            ProcessRecord(pid: pid, ppid: ppid, start: start, hasTerminal: tty, comm: comm, path: path, arguments: args)
        }
        let processes = [
            record(10, 1, start: 0, tty: true, comm: "zsh", args: ["-zsh"]),
            record(11, 10, start: 900, tty: true, comm: "java", args: ["java", "-jar", "/Users/k/TLauncher.jar"]),
            record(12, 11, start: 905, tty: true, comm: "java", args: ["java", "net.minecraft.client.main.Main"]),
            record(13, 10, start: 950, tty: true, comm: "sleep", args: ["sleep", "100"]),
            record(20, 1, start: 500, tty: false, comm: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari"),
            record(21, 1, start: 400, tty: false, comm: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari"),
            record(22, 1, start: 100, tty: false, comm: "Rectangle", path: "/Applications/Rectangle.app/Contents/MacOS/Rectangle"),
        ]
        let apps = AppSelection.select(processes, now: 1000) { process in
            process.comm == "Safari" ? "Safari" : nil
        }
        #expect(apps == [
            OpenApp(name: "Minecraft", detail: "java -jar /Users/k/TLauncher.jar", age: 100, terminal: true),
            OpenApp(name: "Safari", detail: "", age: 600, terminal: false),
        ])
    }

    @Test func argumentsAreParsedFromProcArgs() {
        var raw: [UInt8] = [2, 0, 0, 0]
        raw += Array("/usr/bin/python3".utf8) + [0, 0, 0]
        raw += Array("python3".utf8) + [0] + Array("game.py".utf8) + [0] + Array("HOME=/x".utf8) + [0]
        #expect(ProcessArguments.parse(raw[...]) == ["python3", "game.py"])
    }
}

@Suite struct FakeSystemTests {
    @Test func loadsTheDemoFile() throws {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("tools/demo/kids.json").path) {
            directory.deleteLastPathComponent()
            try #require(directory.path != "/")
        }
        let fake = try FakeSystem.load(path: directory.appendingPathComponent("tools/demo/kids.json").path)
        #expect(fake.hostName() == "kids-laptop")
        #expect(fake.humanUsers().map(\.name) == ["dad", "classes", "gaming"])
        #expect(fake.sessionStates()["gaming"] == .active)
        let gaming = try #require(fake.humanUsers().first { $0.name == "gaming" })
        #expect(fake.openApps(of: gaming).first?.name == "Minecraft")
    }

    @Test func realMacReadsDoNotCrash() {
        let users = MacUserDirectory().humanUsers()
        #expect(users.allSatisfy { $0.uid >= 501 })
        _ = MacSessionMonitor().sessionStates()
        #expect(MacHost().osName().hasPrefix("macOS"))
        if let me = users.first(where: { $0.uid == getuid() }) {
            #expect(MacAppMonitor().openApps(of: me).count <= 15)
        }
    }
}
