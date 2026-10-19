/// A value-owned network with stable node order and validated edge endpoints.
/// Replace a node through upsertNode to preserve its position in keyboard traversal.
public struct GraphNetwork<ID: Hashable & Sendable>: Sendable, Equatable {
    /// Nodes in insertion order.
    public private(set) var nodes: [GraphNode<ID>]
    /// Connections in insertion order. Self-loops are supported.
    public private(set) var edges: [GraphEdge<ID>]

    /// Creates a network, rejecting duplicate node identities, duplicate ordered
    /// edge endpoints, and references to absent nodes.
    public init(nodes: [GraphNode<ID>] = [], edges: [GraphEdge<ID>] = []) throws {
        var identities = Set<ID>()
        for node in nodes {
            guard identities.insert(node.id).inserted else { throw GraphNetworkError.duplicateNode(node.id) }
        }
        self.nodes = nodes
        self.edges = []
        for edge in edges { try addEdge(edge) }
    }

    /// Inserts a node or replaces an existing node without changing its traversal order.
    public mutating func upsertNode(_ node: GraphNode<ID>) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        } else {
            nodes.append(node)
        }
    }

    /// Removes a node and all incoming and outgoing connections.
    public mutating func removeNode(_ id: ID) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.source == id || $0.target == id }
    }

    /// Inserts an edge after validating both endpoints and ordered-pair uniqueness.
    public mutating func addEdge(_ edge: GraphEdge<ID>) throws {
        for id in [edge.source, edge.target] where !nodes.contains(where: { $0.id == id }) {
            throw GraphNetworkError.missingNode(id)
        }
        guard !edges.contains(where: { $0.source == edge.source && $0.target == edge.target }) else {
            throw GraphNetworkError.duplicateEdge(source: edge.source, target: edge.target)
        }
        edges.append(edge)
    }

    /// Removes the connection with these ordered endpoints, if present.
    public mutating func removeEdge(from source: ID, to target: ID) {
        edges.removeAll { $0.source == source && $0.target == target }
    }

    /// Returns reachable adjacent identities in node insertion order.
    /// Undirected edges are traversable in both directions.
    public func neighbors(of id: ID) -> [ID] {
        var adjacent = Set<ID>()
        for edge in edges {
            if edge.source == id { adjacent.insert(edge.target) }
            if !edge.directed && edge.target == id { adjacent.insert(edge.source) }
        }
        return nodes.compactMap { adjacent.contains($0.id) ? $0.id : nil }
    }
}
