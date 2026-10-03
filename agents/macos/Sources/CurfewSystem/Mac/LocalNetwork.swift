import Darwin

public enum LocalNetwork {
    public static func lanAddress() -> String? {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var remote = ipv4(address: "192.0.2.1", port: 9)
        let connected = withUnsafePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return nil }
        var local = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        guard named == 0 else { return nil }
        var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &local.sin_addr, &text, socklen_t(text.count)) != nil else { return nil }
        return String(decoding: text.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    public static func hardwareAddress(of ip: String) -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var name: String?
        var links: [String: String] = [:]
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr else { continue }
            let interface = String(cString: entry.pointee.ifa_name)
            switch Int32(address.pointee.sa_family) {
            case AF_INET:
                var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { inet in
                    var raw = inet.pointee.sin_addr
                    _ = inet_ntop(AF_INET, &raw, &text, socklen_t(text.count))
                }
                if String(decoding: text.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self) == ip { name = interface }
            case AF_LINK:
                address.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { link in
                    let length = Int(link.pointee.sdl_alen)
                    guard length == 6 else { return }
                    guard let start = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) else { return }
                    let skip = start + Int(link.pointee.sdl_nlen)
                    guard skip + length <= Int(link.pointee.sdl_len) else { return }
                    let raw = UnsafeRawPointer(link)
                    links[interface] = (0..<length).map { String(format: "%02x", raw.load(fromByteOffset: skip + $0, as: UInt8.self)) }.joined(separator: ":")
                }
            default:
                break
            }
        }
        return name.flatMap { links[$0] }
    }

    public static func agentRunning(port: UInt16) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var local = ipv4(address: "127.0.0.1", port: port)
        return withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }

    private static func ipv4(address: String, port: UInt16) -> sockaddr_in {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = port.bigEndian
        inet_pton(AF_INET, address, &socketAddress.sin_addr)
        return socketAddress
    }
}
