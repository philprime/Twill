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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(name: "Twill"),
        .testTarget(name: "TwillTests", dependencies: ["Twill"]),
        .testTarget(name: "TwillIntegrationTests", dependencies: ["Twill"]),
    ]
)
