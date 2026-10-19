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
    ],
    targets: [
        .target(name: "Twill", dependencies: ["TwillTextRendering"]),

        // Unit & Integration Testing
        .testTarget(name: "TwillTests", dependencies: ["Twill", "TwillTextRendering"]),
        .testTarget(name: "TwillIntegrationTests", dependencies: ["Twill"]),

        // Benchmark Testing
        .executableTarget(name: "TwillBenchmarks", dependencies: ["Twill"]),
        .testTarget(name: "TwillBenchmarkTests", dependencies: ["TwillBenchmarks"]),

        // Text Render Engine
        .target(name: "TwillTextRendering", dependencies: ["CHarfBuzz"]),
        .testTarget(
            name: "TwillTextRenderingTests", dependencies: ["TwillTextRendering", "CHarfBuzz"],
            exclude: ["Fixtures/make-test-font.py"], resources: [.copy("Fixtures/TwillTest.ttf")]),
        .target(
            name: "CHarfBuzz",
            path: "ThirdParty/HarfBuzz",
            sources: [
                "upstream/src/harfbuzz.cc",
                "upstream/src/hb-raster-draw.cc",
                "upstream/src/hb-raster-image.cc",
            ],
            publicHeadersPath: "include"
        ),

        // Extension: Graphs
        .target(name: "TwillGraphs", dependencies: ["Twill"]),
        .testTarget(name: "TwillGraphsTests", dependencies: ["Twill", "TwillGraphs"]),
    ],
    cxxLanguageStandard: .cxx11
)
