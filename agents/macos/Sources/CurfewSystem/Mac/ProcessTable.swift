import Darwin

struct ProcessRecord: Sendable, Equatable {
    let pid: Int32
    let ppid: Int32
    let start: Int
    let hasTerminal: Bool
    let comm: String
    let path: String
    let arguments: [String]
}

enum ProcessTable {
    private static let pathCapacity = 4096
    private static let noDevice = UInt32.max

    static func snapshot(uid: uid_t) -> [ProcessRecord] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard found > 0 else { return [] }
        var arguments = ProcessArguments()
        return pids.prefix(Int(found)).compactMap { pid in
            record(pid: pid, uid: uid, arguments: &arguments)
        }
    }

    private static func record(pid: pid_t, uid: uid_t, arguments: inout ProcessArguments) -> ProcessRecord? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size, info.pbi_uid == uid else { return nil }
        let terminal = info.e_tdev != noDevice && info.pbi_flags & UInt32(PROC_FLAG_CONTROLT) != 0
        let comm = withUnsafeBytes(of: info.pbi_comm) { cString($0) }
        return ProcessRecord(
            pid: pid,
            ppid: Int32(bitPattern: info.pbi_ppid),
            start: Int(info.pbi_start_tvsec),
            hasTerminal: terminal,
            comm: comm,
            path: path(of: pid),
            arguments: terminal ? arguments.read(pid: pid) ?? [comm] : []
        )
    }

    private static func path(of pid: pid_t) -> String {
        var buffer = [UInt8](repeating: 0, count: pathCapacity)
        let length = buffer.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
        return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : ""
    }

    private static func cString(_ bytes: UnsafeRawBufferPointer) -> String {
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}

struct ProcessArguments {
    private var buffer: [UInt8] = []

    mutating func read(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        if buffer.isEmpty {
            var limit: Int32 = 0
            var limitSize = MemoryLayout<Int32>.size
            var limitMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
            guard sysctl(&limitMib, 2, &limit, &limitSize, nil, 0) == 0, limit > 0 else { return nil }
            buffer = [UInt8](repeating: 0, count: Int(limit))
        }
        var size = buffer.count
        let status = buffer.withUnsafeMutableBytes { sysctl(&mib, 3, $0.baseAddress, &size, nil, 0) }
        guard status == 0, size > MemoryLayout<Int32>.size else { return nil }
        return Self.parse(buffer.prefix(size))
    }

    static func parse(_ data: ArraySlice<UInt8>) -> [String]? {
        guard data.count > 4 else { return nil }
        let start = data.startIndex
        let argc = Int(data[start]) | Int(data[start + 1]) << 8 | Int(data[start + 2]) << 16 | Int(data[start + 3]) << 24
        var index = start + 4
        while index < data.endIndex, data[index] != 0 { index += 1 }
        while index < data.endIndex, data[index] == 0 { index += 1 }
        var out: [String] = []
        while out.count < argc, index < data.endIndex {
            let begin = index
            while index < data.endIndex, data[index] != 0 { index += 1 }
            out.append(String(decoding: data[begin..<index], as: UTF8.self))
            index += 1
        }
        return out.isEmpty ? nil : out
    }
}
