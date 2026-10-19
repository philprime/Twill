import Foundation
import Testing

@testable import PackageExplorer
@testable import Twill

@Suite("Package build and discovery")
@MainActor
struct PackageLoaderTests {
    @Test("A real package builds and produces its own type graph", .timeLimit(.minutes(1)))
    func discovery() async throws {
        // -- Arrange --
        let fixture = try #require(
            Bundle.module.url(
                forResource: "Package", withExtension: "swift", subdirectory: "Fixtures/ToyPackage"))
        let loader = PackageLoader()

        // -- Act --
        let package = try await loader.load(manifest: fixture)

        // -- Assert --
        #expect(package.name == "ExplorerFixture")
        #expect(
            Set(package.graph.types.values.map(\.name)) == [
                "Service", "Worker", "Worker.Status", "Base", "Derived", "ActorWorker", "InternalType", "Hidden",
            ])
        #expect(package.graph.relationships.contains { $0.kind == .conformance })
        #expect(package.graph.relationships.contains { $0.kind == .nesting })
        #expect(package.graph.relationships.contains { $0.kind == .inheritance })
        #expect(package.graph.types.values.first { $0.name == "ActorWorker" }?.kind == .actor)
        #expect(package.positions.count == 8)
        let renderer = ViewRenderer.make(PackageExplorerView(package: package))
        let frame = renderer.render(.now, proposal: .init(width: 100, height: 30))
        #expect(frame.grid?.images.count == 1)
        #expect(frame.nextUpdate == nil)
        #expect(renderer.handle(.character("/")))
        _ = renderer.render(.now, proposal: .init(width: 100, height: 30))
        #expect(renderer.handle(.character("W")))
        let filtered = renderer.render(.now, proposal: .init(width: 100, height: 30))
        #expect(filtered.grid?.images.count == 1)
        #expect(filtered.grid?.images != frame.grid?.images)
    }

    @Test("A path that is not a manifest is rejected before starting Swift")
    func invalidManifest() async {
        // -- Arrange --
        let manifest = URL(fileURLWithPath: "/does/not/exist/Package.swift")

        // -- Act --
        // -- Assert --
        await #expect(throws: PackageExplorerError.self) {
            try await PackageLoader().load(manifest: manifest)
        }
    }
}
