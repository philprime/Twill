// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "ActivityMonitor",
    platforms: [.macOS(.v15)],
    dependencies: [.package(name: "Twill", path: "../../")],
    targets: [
        .executableTarget(name: "ActivityMonitor", dependencies: ["Twill"]),
        .testTarget(name: "ActivityMonitorTests", dependencies: ["ActivityMonitor"]),
    ]
)
