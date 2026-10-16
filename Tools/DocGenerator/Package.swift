// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "DocGenerator",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(name: "Twill", path: "../../")
    ],
    targets: [
        .executableTarget(name: "DocGenerator", dependencies: ["Twill"])
    ]
)
