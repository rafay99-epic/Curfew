public enum Limits {
    public static let protocolVersion = 1
    public static let livePort: UInt16 = 787
    public static let dryRunPort: UInt16 = 8787
    public static let maxBody = 16384
    public static let maxHead = 16384
    public static let nonceLifetime: Double = 60
    public static let noncesPerAddress = 32
    public static let nonceCapacity = 4096
    public static let connectionsPerAddress = 8
    public static let requestTimeoutSeconds = 10
    public static let maxPhoneNameLength = 40
    public static let removedPhonesKept = 50
}
