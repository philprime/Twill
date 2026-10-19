import Foundation
import TwillGraphs

struct PackageGraph: Sendable {
    let network: GraphNetwork<String>
    let types: [String: PackageType]
    let relationships: [PackageRelationship]

    var modules: [String] { Set(types.values.map(\.module)).sorted() }

    func filtered(query: String, module: String?, kind: PackageTypeKind?) -> GraphNetwork<String> {
        var result = network
        for node in network.nodes {
            guard let type = types[node.id] else { continue }
            let matches =
                (query.isEmpty || type.name.localizedCaseInsensitiveContains(query))
                && (module == nil || type.module == module) && (kind == nil || type.kind == kind)
            if !matches { result.removeNode(node.id) }
        }
        return result
    }
}
