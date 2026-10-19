// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Twill",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "Twill", targets: ["Twill"]),
        .library(name: "TwillGraphs", targets: ["TwillGraphs"]),
        .executable(name: "PackageExplorer", targets: ["PackageExplorer"]),
    ],
    targets: [
        .target(name: "Twill"),
        .target(name: "TwillGraphs", dependencies: ["Twill"]),
        .testTarget(name: "TwillGraphsTests", dependencies: ["Twill", "TwillGraphs"]),
        .executableTarget(name: "PackageExplorer", dependencies: ["Twill", "TwillGraphs"]),
        .testTarget(
            name: "PackageExplorerTests", dependencies: ["PackageExplorer", "Twill"], resources: [.copy("Fixtures")]),
        .executableTarget(name: "TwillBenchmarks", dependencies: ["Twill"]),
        .testTarget(name: "TwillBenchmarkTests", dependencies: ["TwillBenchmarks"]),
        .testTarget(name: "TwillTests", dependencies: ["Twill"]),
        .testTarget(name: "TwillIntegrationTests", dependencies: ["Twill"]),
    ]
)
