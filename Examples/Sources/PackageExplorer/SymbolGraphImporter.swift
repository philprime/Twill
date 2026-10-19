import Foundation
import Twill
import TwillGraphs

struct SymbolGraphImporter {
    private static let palette = [
        PixelColor(red: 166, green: 139, blue: 250), PixelColor(red: 97, green: 175, blue: 239),
        PixelColor(red: 152, green: 195, blue: 121), PixelColor(red: 229, green: 192, blue: 123),
        PixelColor(red: 224, green: 108, blue: 117), PixelColor(red: 86, green: 182, blue: 194),
    ]

    func load(_ data: [Data], modules: Set<String>) throws -> PackageGraph {
        let graphs = try data.map { try JSONDecoder().decode(SwiftSymbolGraph.self, from: $0) }
            .filter { modules.contains($0.module.name) }
        var types: [String: PackageType] = [:]
        for graph in graphs {
            for symbol in graph.symbols {
                let fragments = symbol.declarationFragments?.map(\.spelling) ?? []
                guard let kind = PackageTypeKind.resolve(symbol.kind.identifier, declaration: fragments) else {
                    continue
                }
                let name =
                    symbol.pathComponents.isEmpty ? symbol.names.title : symbol.pathComponents.joined(separator: ".")
                types[symbol.identifier.precise] = PackageType(
                    id: symbol.identifier.precise, name: name, module: graph.module.name, kind: kind,
                    declaration: fragments.joined(), source: symbol.location.flatMap { URL(string: $0.uri) },
                    line: symbol.location.map { $0.position.line + 1 })
            }
        }
        let moduleNames = modules.sorted()
        let nodes = types.values.sorted {
            ($0.module, $0.name, $0.id) < ($1.module, $1.name, $1.id)
        }.map { type in
            let index = moduleNames.firstIndex(of: type.module)!
            return GraphNode(id: type.id, label: type.name, color: Self.palette[index % Self.palette.count])
        }
        var network = try GraphNetwork(nodes: nodes, edges: [])
        var relationships: [PackageRelationship] = []
        for graph in graphs {
            for edge in graph.relationships {
                guard let kind = PackageRelationship.Kind(rawValue: edge.kind),
                    types[edge.source] != nil, types[edge.target] != nil
                else { continue }
                guard !relationships.contains(where: { $0.source == edge.source && $0.target == edge.target }) else {
                    continue
                }
                relationships.append(PackageRelationship(source: edge.source, target: edge.target, kind: kind))
                try network.addEdge(GraphEdge(from: edge.source, to: edge.target, directed: true, color: kind.color))
            }
        }
        return PackageGraph(network: network, types: types, relationships: relationships)
    }
}
