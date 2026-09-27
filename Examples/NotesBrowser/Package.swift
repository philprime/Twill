// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "NotesBrowser",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(name: "Twill", path: "../../")
    ],
    targets: [
        .executableTarget(name: "NotesBrowser", dependencies: ["Twill"])
    ]
)
