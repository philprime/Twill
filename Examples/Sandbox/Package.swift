// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Sandbox",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(name: "Twill", path: "../../")
    ],
    targets: [
        .executableTarget(name: "Sandbox", dependencies: ["Twill"])
    ]
)
