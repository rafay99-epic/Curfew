import CurfewProtocol
import Darwin

public enum ControlSocketError: Error, Sendable, Equatable {
    case unreachable
    case denied
    case broken
}

public enum ControlSocket {
    public static func connect(_ path: String, timeout: Int = 5) throws(ControlSocketError) -> Int32 {
        var address = sockaddr_un()
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw .unreachable }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .broken }
        prepare(descriptor, timeout: timeout)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else {
            let code = errno
            close(descriptor)
            switch code {
            case EACCES, EPERM: throw .denied
            case ENOENT, ECONNREFUSED, ENOTDIR: throw .unreachable
            default: throw .broken
            }
        }
        return descriptor
    }

    public static func exchange(_ path: String, _ request: JSONValue) throws(ControlSocketError) -> JSONValue {
        let descriptor = try connect(path)
        defer { close(descriptor) }
        guard writeLine(descriptor, request.text), let line = readLine(descriptor, limit: 1 << 20),
              let reply = JSONValue(parsing: line)
        else { throw .broken }
        if ControlError(reply: reply) == .denied { throw .denied }
        return reply
    }

    public static func prepare(_ descriptor: Int32, timeout: Int) {
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) & ~O_NONBLOCK)
        var on: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var limit = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
    }

    public static func readLine(_ descriptor: Int32, limit: Int) -> String? {
        var line: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 4096)
        while line.count <= limit {
            let count = chunk.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { return line.isEmpty ? nil : String(decoding: line, as: UTF8.self) }
            let received = chunk.prefix(count)
            if let end = received.firstIndex(of: 0x0a) {
                line += received[..<end]
                return line.count <= limit ? String(decoding: line, as: UTF8.self) : nil
            }
            line += received
        }
        return nil
    }

    @discardableResult
    public static func writeLine(_ descriptor: Int32, _ text: String) -> Bool {
        let bytes = Array((text + "\n").utf8)
        var sent = 0
        while sent < bytes.count {
            let count = bytes[sent...].withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { return false }
            sent += count
        }
        return true
    }
}
