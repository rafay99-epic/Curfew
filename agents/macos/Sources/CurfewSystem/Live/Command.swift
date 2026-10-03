import Foundation

public struct CommandResult: Sendable, Equatable {
    public let status: Int32
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

public enum Command {
    public static func run(_ argv: [String], input: String? = nil) -> CommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: argv[0])
        process.arguments = Array(argv.dropFirst())
        process.standardOutput = output
        process.standardError = output
        let feed = input.map { _ in Pipe() }
        process.standardInput = feed ?? FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandResult(status: 127, output: "\(error)")
        }
        if let feed, let input {
            try? feed.fileHandleForWriting.write(contentsOf: Data(input.utf8))
            try? feed.fileHandleForWriting.close()
        }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: text)
    }
}
