import CurfewControl
import CurfewProtocol
import Darwin
import Dispatch

public enum ControlServerError: Error, Sendable, CustomStringConvertible {
    case pathTooLong(String)
    case inUse(String)
    case notASocket(String)
    case system(String, Int32)

    public var description: String {
        switch self {
        case .pathTooLong(let path): "the control socket path is too long: \(path)"
        case .inUse(let path): "another Curfew service is answering on \(path)"
        case .notASocket(let path): "\(path) exists and is not a socket"
        case .system(let call, let code): "\(call) failed: \(String(cString: strerror(code)))"
        }
    }
}

public final class ControlServer: Sendable {
    public typealias Handler = @Sendable (String) async -> String

    public enum Access: Sendable {
        case owner
        case admins
    }

    static let timeoutSeconds = 5

    public let path: String
    private let source: any DispatchSourceRead

    public init(path: String, access: Access, policy: PeerPolicy, handler: @escaping Handler) throws {
        var address = sockaddr_un()
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw ControlServerError.pathTooLong(path) }
        try Self.clearStale(path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ControlServerError.system("socket", errno) }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        do {
            try Self.check("fcntl", fcntl(descriptor, F_SETFD, FD_CLOEXEC))
            try Self.check("bind", withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            })
            switch access {
            case .owner:
                try Self.check("chmod", chmod(path, 0o600))
            case .admins:
                try Self.check("chown", chown(path, 0, PeerPolicy.adminGroup))
                try Self.check("chmod", chmod(path, 0o660))
            }
            try Self.check("listen", listen(descriptor, 16))
            try Self.check("fcntl", fcntl(descriptor, F_SETFL, O_NONBLOCK))
        } catch {
            close(descriptor)
            unlink(path)
            throw error
        }
        self.path = path
        source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: DispatchQueue(label: "curfew.control"))
        source.setEventHandler {
            Self.acceptPending(on: descriptor, policy: policy, handler: handler)
        }
        source.setCancelHandler {
            close(descriptor)
        }
    }

    public func start() {
        source.activate()
    }

    public func stop() {
        source.cancel()
        unlink(path)
    }

    private static func check(_ call: String, _ result: Int32) throws {
        if result < 0 { throw ControlServerError.system(call, errno) }
    }

    private static func clearStale(_ path: String) throws {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            if errno == ENOENT { return }
            throw ControlServerError.system("lstat", errno)
        }
        guard info.st_mode & S_IFMT == S_IFSOCK else { throw ControlServerError.notASocket(path) }
        if let live = try? ControlSocket.connect(path, timeout: 1) {
            close(live)
            throw ControlServerError.inUse(path)
        }
        try check("unlink", unlink(path))
    }

    private static func acceptPending(on descriptor: Int32, policy: PeerPolicy, handler: @escaping Handler) {
        while true {
            let client = accept(descriptor, nil, nil)
            guard client >= 0 else { return }
            ControlSocket.prepare(client, timeout: timeoutSeconds)
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, policy.allows(uid: uid, gid: gid) else {
                ControlSocket.writeLine(client, ControlError.denied.json.text)
                close(client)
                continue
            }
            DispatchQueue.global().async {
                guard let line = ControlSocket.readLine(client, limit: Limits.maxBody) else {
                    close(client)
                    return
                }
                Task {
                    let reply = await handler(line)
                    DispatchQueue.global().async {
                        ControlSocket.writeLine(client, reply)
                        close(client)
                    }
                }
            }
        }
    }
}
