import CurfewProtocol
import Foundation

public struct HTTPRequest: Sendable, Equatable {
    public let method: String
    public let target: String
    public let body: [UInt8]?

    public init(method: String, target: String, body: [UInt8]?) {
        self.method = method
        self.target = target
        self.body = body
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public let status: Int
    public let body: JSONValue

    public init(status: Int, body: JSONValue) {
        self.status = status
        self.body = body
    }

    public init(_ error: WireError) {
        self.init(status: error.status, body: error.body)
    }

    var bytes: [UInt8] {
        let payload = body.bytes
        let head = [
            "HTTP/1.1 \(status) \(Self.reason(status))",
            "Server: Curfew",
            "Content-Type: application/json",
            "Content-Length: \(payload.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "", "",
        ].joined(separator: "\r\n")
        return Array(head.utf8) + payload
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 409: "Conflict"
        case 501: "Not Implemented"
        default: "Internal Server Error"
        }
    }
}

struct RequestHead: Sendable, Equatable {
    let method: String
    let target: String
    let contentLength: Int?

    var expectedBody: Int? {
        guard method == "POST", let contentLength, (1...Limits.maxBody).contains(contentLength) else { return nil }
        return contentLength
    }

    static func split(_ buffer: [UInt8]) -> (head: ArraySlice<UInt8>, rest: ArraySlice<UInt8>)? {
        guard buffer.count >= 2 else { return nil }
        for index in 1..<buffer.count where buffer[index] == 0x0a {
            if buffer[index - 1] == 0x0a {
                return (buffer[..<(index - 1)], buffer[(index + 1)...])
            }
            if index >= 3, buffer[index - 1] == 0x0d, buffer[index - 2] == 0x0a, buffer[index - 3] == 0x0d {
                return (buffer[..<(index - 3)], buffer[(index + 1)...])
            }
        }
        return nil
    }

    static func parse(_ head: ArraySlice<UInt8>) -> RequestHead? {
        let lines = head.split(separator: 0x0a, omittingEmptySubsequences: false).map { line in
            String(decoding: line.last == 0x0d ? line.dropLast() : line, as: UTF8.self)
        }
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/") else { return nil }
        let length = lines.dropFirst().lazy.compactMap(header).first { $0.name == "content-length" }?.value
        return RequestHead(method: String(parts[0]), target: String(parts[1]), contentLength: length.flatMap(number))
    }

    private static func header(_ line: String) -> (name: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        return (line[..<colon].lowercased(), line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
    }

    private static func number(_ text: String) -> Int? {
        guard !text.isEmpty, text.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
        return Int(text)
    }
}
