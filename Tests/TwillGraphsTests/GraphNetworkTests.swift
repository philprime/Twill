import Testing
import Twill

@testable import TwillGraphs

@Suite("Graph networks")
struct GraphNetworkTests {
    @Test("Removing a node removes incident edges and preserves unrelated nodes")
    func mutation() throws {
        // -- Arrange --
        var graph = try GraphNetwork(
            nodes: [GraphNode(id: "a", label: "A"), GraphNode(id: "b", label: "B"), GraphNode(id: "c", label: "C")],
            edges: [GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c")])

        // -- Act --
        graph.upsertNode(GraphNode(id: "a", label: "Updated"))
        graph.removeNode("b")

        // -- Assert --
        #expect(graph.nodes.map(\.id) == ["a", "c"])
        #expect(graph.nodes.first?.label == "Updated")
        #expect(graph.edges.isEmpty)
    }

    @Test("Invalid edges and duplicate identities are rejected without partial mutation")
    func validation() throws {
        // -- Arrange --
        var graph = try GraphNetwork(nodes: [GraphNode(id: 1)], edges: [])

        // -- Act --
        #expect(throws: GraphNetworkError<Int>.missingNode(2)) {
            try graph.addEdge(GraphEdge(from: 1, to: 2))
        }
        #expect(throws: GraphNetworkError<Int>.duplicateNode(1)) {
            try GraphNetwork(nodes: [GraphNode(id: 1), GraphNode(id: 1)], edges: [])
        }

        // -- Assert --
        #expect(graph.edges.isEmpty)
        #expect(graph.nodes.map(\.id) == [1])
    }

    @Test("Neighbors respect edge direction and edge removal")
    func neighbors() throws {
        // -- Arrange --
        var graph = try GraphNetwork(
            nodes: [GraphNode(id: 1), GraphNode(id: 2), GraphNode(id: 3)],
            edges: [GraphEdge(from: 1, to: 2, directed: true), GraphEdge(from: 2, to: 3)])

        // -- Act --
        let incoming = graph.neighbors(of: 2)
        let outgoing = graph.neighbors(of: 1)
        graph.removeEdge(from: 2, to: 3)

        // -- Assert --
        #expect(incoming == [3])
        #expect(outgoing == [2])
        #expect(graph.neighbors(of: 2).isEmpty)
        #expect(graph.neighbors(of: 3).isEmpty)
    }

    @Test("Duplicate edges are rejected while self loops remain representable")
    func duplicateEdges() throws {
        // -- Arrange --
        var graph = try GraphNetwork(nodes: [GraphNode(id: "a")], edges: [])

        // -- Act --
        try graph.addEdge(GraphEdge(from: "a", to: "a"))
        #expect(throws: GraphNetworkError<String>.duplicateEdge(source: "a", target: "a")) {
            try graph.addEdge(GraphEdge(from: "a", to: "a"))
        }

        // -- Assert --
        #expect(graph.edges.count == 1)
        #expect(graph.neighbors(of: "a") == ["a"])
    }
}
