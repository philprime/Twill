import Foundation
import Twill
import TwillGraphs

struct LoadedPackage {
    let name: String
    let graph: PackageGraph
    let positions: [String: PixelPoint]
}

@MainActor
struct PackageLoader {
    private struct Description: Decodable {
        struct Target: Decodable {
            let c99name: String
            let type: String
            let moduleType: String

            enum CodingKeys: String, CodingKey {
                case c99name, type
                case moduleType = "module_type"
            }
        }
        let name: String
        let targets: [Target]
    }

    func load(manifest: URL, progress: (String) -> Void = { _ in }) async throws -> LoadedPackage {
        var isDirectory: ObjCBool = false
        guard manifest.lastPathComponent == "Package.swift",
            FileManager.default.fileExists(atPath: manifest.path, isDirectory: &isDirectory), !isDirectory.boolValue
        else { throw PackageExplorerError.invalidManifest(manifest.path) }

        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PackageExplorer-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let scratch = workspace.appendingPathComponent("build")
        let common = ["--package-path", manifest.deletingLastPathComponent().path, "--scratch-path", scratch.path]
        let command = SwiftPackageCommand()
        progress("Reading package targets…")
        let descriptionData = try await command.run(
            ["package"] + common + ["describe", "--type", "json"], logs: workspace)
        let description = try JSONDecoder().decode(Description.self, from: Data(descriptionData.utf8))
        let modules = Set(
            description.targets.filter { $0.moduleType == "SwiftTarget" && $0.type != "test" }.map(\.c99name))
        progress("Building and extracting type symbols…")
        _ = try await command.run(
            ["package"] + common + ["dump-symbol-graph", "--minimum-access-level", "private"], logs: workspace)
        let files =
            FileManager.default.enumerator(at: scratch, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.lastPathComponent.hasSuffix(".symbols.json") }
            .sorted { $0.path < $1.path } ?? []
        guard !files.isEmpty else { throw PackageExplorerError.noSymbolGraphs }
        let graph = try SymbolGraphImporter().load(files.map { try Data(contentsOf: $0) }, modules: modules)
        progress("Laying out \(graph.types.count) types…")
        let positions = ForceDirectedLayout().positions(for: graph.network)
        return LoadedPackage(name: description.name, graph: graph, positions: positions)
    }
}
