// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Curfew",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "curfew", targets: ["curfew"]),
        .executable(name: "CurfewApp", targets: ["CurfewApp"]),
    ],
    targets: [
        .target(name: "CurfewProtocol"),
        .target(name: "CurfewSystem", dependencies: ["CurfewProtocol"]),
        .target(name: "CurfewControl", dependencies: ["CurfewProtocol"], plugins: ["VersionPlugin"]),
        .target(name: "CurfewAgent", dependencies: ["CurfewProtocol", "CurfewSystem", "CurfewControl"]),
        .executableTarget(name: "curfew", dependencies: ["CurfewAgent", "CurfewSystem", "CurfewProtocol", "CurfewControl"]),
        .executableTarget(name: "CurfewApp", dependencies: ["CurfewControl", "CurfewProtocol"]),
        .plugin(name: "VersionPlugin", capability: .buildTool()),
        .testTarget(name: "CurfewProtocolTests", dependencies: ["CurfewProtocol"]),
        .testTarget(name: "CurfewSystemTests", dependencies: ["CurfewSystem"]),
        .testTarget(name: "CurfewAgentTests", dependencies: ["CurfewAgent", "CurfewSystem", "CurfewProtocol"]),
        .testTarget(name: "CurfewCLITests", dependencies: ["curfew", "CurfewControl"]),
        .testTarget(name: "CurfewControlTests", dependencies: ["CurfewControl", "CurfewAgent", "CurfewProtocol", "CurfewSystem"]),
        .testTarget(name: "CurfewAppTests", dependencies: ["CurfewApp", "CurfewControl", "CurfewAgent", "CurfewProtocol", "CurfewSystem", "curfew"]),
    ]
)
