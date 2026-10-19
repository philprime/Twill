import Foundation
import Testing

@testable import PackageExplorer

@Suite("Package symbol import")
struct SymbolGraphImporterTests {
    @Test("Own types and relationships are imported without external or member symbols")
    func typesAndRelationships() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "module": {"name": "Demo"},
              "symbols": [
                {"identifier":{"precise":"base"},"kind":{"identifier":"swift.protocol"},
                 "names":{"title":"Service"},"pathComponents":["Service"],
                 "declarationFragments":[{"spelling":"protocol Service"}]},
                {"identifier":{"precise":"worker"},"kind":{"identifier":"swift.class"},
                 "names":{"title":"Worker"},"pathComponents":["Worker"],
                 "declarationFragments":[{"spelling":"actor"},{"spelling":" Worker"}],
                 "location":{"uri":"file:///tmp/Worker.swift","position":{"line":4,"character":0}}},
                {"identifier":{"precise":"method"},"kind":{"identifier":"swift.method"},
                 "names":{"title":"run()"},"pathComponents":["Worker","run()"]}
              ],
              "relationships": [
                {"source":"worker","target":"base","kind":"conformsTo"},
                {"source":"method","target":"worker","kind":"memberOf"},
                {"source":"worker","target":"external","kind":"inheritsFrom"}
              ]
            }
            """.utf8)

        // -- Act --
        let graph = try SymbolGraphImporter().load([data, data], modules: ["Demo"])

        // -- Assert --
        #expect(graph.types.count == 2)
        #expect(graph.types["worker"]?.kind == .actor)
        #expect(graph.types["worker"]?.line == 5)
        #expect(graph.types["worker"]?.declaration == "actor Worker")
        #expect(graph.network.edges.count == 1)
        #expect(graph.relationships.first?.kind == .conformance)
        #expect(graph.network.nodes.map(\.label) == ["Service", "Worker"])
    }

    @Test("Dependency modules are excluded and nested types retain their qualified name")
    func modulesAndNesting() throws {
        // -- Arrange --
        let own = Data(
            """
            {"module":{"name":"Own"},"symbols":[
              {"identifier":{"precise":"outer"},"kind":{"identifier":"swift.struct"},
               "names":{"title":"Outer"},"pathComponents":["Outer"]},
              {"identifier":{"precise":"inner"},"kind":{"identifier":"swift.enum"},
               "names":{"title":"Inner"},"pathComponents":["Outer","Inner"]}
             ],"relationships":[{"source":"inner","target":"outer","kind":"memberOf"}]}
            """.utf8)
        let dependency = Data(
            """
            {"module":{"name":"Dependency"},"symbols":[
              {"identifier":{"precise":"other"},"kind":{"identifier":"swift.class"},
               "names":{"title":"Other"},"pathComponents":["Other"]}
            ],"relationships":[]}
            """.utf8)

        // -- Act --
        let graph = try SymbolGraphImporter().load([own, dependency], modules: ["Own"])
        let filtered = graph.filtered(query: "outer.inner", module: nil, kind: .enumeration)

        // -- Assert --
        #expect(graph.types["other"] == nil)
        #expect(graph.types["inner"]?.name == "Outer.Inner")
        #expect(graph.relationships.first?.kind == .nesting)
        #expect(filtered.nodes.map(\.id) == ["inner"])
        #expect(filtered.edges.isEmpty)
    }

    @Test("Malformed symbol data is surfaced rather than displayed as an empty graph")
    func invalidData() {
        // -- Arrange --
        let data = Data("not JSON".utf8)

        // -- Act --
        // -- Assert --
        #expect(throws: DecodingError.self) {
            try SymbolGraphImporter().load([data], modules: ["Own"])
        }
    }
}
