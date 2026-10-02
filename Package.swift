// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "StayAwake"),
    ]
)
