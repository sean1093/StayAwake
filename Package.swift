// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "StayAwakeCore"),
        .executableTarget(name: "StayAwake", dependencies: ["StayAwakeCore"]),
        .testTarget(name: "StayAwakeCoreTests", dependencies: ["StayAwakeCore"]),
    ]
)
