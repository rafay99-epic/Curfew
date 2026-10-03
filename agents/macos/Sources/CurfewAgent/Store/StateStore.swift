import CurfewProtocol
import Foundation

public enum StateStoreError: Error, Sendable {
    case directory(Int32)
    case lock(Int32)
    case write(Int32)
}

public actor StateStore {
    public nonisolated let directory: String
    private var statePath: String { directory + "/state.json" }
    private var lockPath: String { directory + "/lock" }

    public init(directory: String) {
        self.directory = directory
    }

    public func read() throws -> AgentState {
        try withLock {
            let state = try load()
            if state.dirty { try save(state.value) }
            return state.value
        }
    }

    public func update<Result: Sendable>(_ body: @Sendable (inout AgentState) throws -> Result) throws -> Result {
        try withLock {
            var state = try load().value
            let result = try body(&state)
            try save(state)
            return result
        }
    }

    private func withLock<Result>(_ body: () throws -> Result) throws -> Result {
        if mkdir(directory, 0o700) != 0, errno != EEXIST {
            throw StateStoreError.directory(errno)
        }
        let descriptor = open(lockPath, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw StateStoreError.lock(errno) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StateStoreError.lock(errno) }
        return try body()
    }

    private func load() throws -> (value: AgentState, dirty: Bool) {
        guard let data = FileManager.default.contents(atPath: statePath),
              var state = try? JSONDecoder().decode(AgentState.self, from: data)
        else { return (AgentState(id: Token.random(bytes: 8)), true) }
        guard state.id.isEmpty else { return (state, false) }
        state.id = Token.random(bytes: 8)
        return (state, true)
    }

    private func save(_ state: AgentState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        let temporary = statePath + ".tmp"
        let descriptor = open(temporary, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw StateStoreError.write(errno) }
        let written = data.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
        let synced = fsync(descriptor) == 0
        close(descriptor)
        guard written == data.count, synced, rename(temporary, statePath) == 0 else {
            throw StateStoreError.write(errno)
        }
    }
}
