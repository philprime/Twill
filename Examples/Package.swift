// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TwillExamples",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ActivityMonitor", targets: ["ActivityMonitor"]),
        .executable(name: "Clock", targets: ["Clock"]),
        .executable(name: "FileBrowser", targets: ["FileBrowser"]),
        .executable(name: "NotesBrowser", targets: ["NotesBrowser"]),
        .executable(name: "Sandbox", targets: ["Sandbox"]),
    ],
    dependencies: [.package(name: "Twill", path: "../")],
    targets: [
        .executableTarget(name: "ActivityMonitor", dependencies: ["Twill"]),
        .executableTarget(name: "Clock", dependencies: ["Twill"]),
        .executableTarget(name: "FileBrowser", dependencies: ["Twill"]),
        .executableTarget(name: "NotesBrowser", dependencies: ["Twill"]),
        .executableTarget(name: "Sandbox", dependencies: ["Twill"]),
        .testTarget(name: "ActivityMonitorTests", dependencies: ["ActivityMonitor"]),
    ]
)
