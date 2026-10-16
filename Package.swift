// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Twill",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "Twill", targets: ["Twill"])
    ],
    targets: [
        .target(name: "Twill"),
        .executableTarget(name: "TwillBenchmarks", dependencies: ["Twill"]),
        .testTarget(name: "TwillBenchmarkTests", dependencies: ["TwillBenchmarks"]),
        .testTarget(name: "TwillTests", dependencies: ["Twill"]),
        .testTarget(name: "TwillIntegrationTests", dependencies: ["Twill"]),
    ]
)
