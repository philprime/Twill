// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ExplorerFixture",
    products: [.library(name: "Model", targets: ["Model"])],
    targets: [.target(name: "Model")])
