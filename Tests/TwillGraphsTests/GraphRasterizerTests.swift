import Foundation
import Testing

@testable import Twill
@testable import TwillGraphs

@Suite("Graph rasterization")
@MainActor
struct GraphRasterizerTests {
    @Test("Edges connect colored nodes while unrelated pixels remain transparent")
    func nodesAndEdges() throws {
        // -- Arrange --
        let graph = try network(directed: false)
        let positions = [1: PixelPoint(x: -1, y: 0), 2: PixelPoint(x: 1, y: 0)]

        // -- Act --
        let data = try render(graph, positions: positions)

        // -- Assert --
        #expect(Array(data[(4 * (50 * 100 + 20))..<(4 * (50 * 100 + 20) + 4)]) == [255, 0, 0, 255])
        #expect(data[4 * (50 * 100 + 50) + 1] == 255)
        #expect(data[3] == 0)
    }

    @Test("Directed edges add arrowheads outside the line segment")
    func arrows() throws {
        // -- Arrange --
        let positions = [1: PixelPoint(x: -1, y: 0), 2: PixelPoint(x: 1, y: 0)]
        let directedGraph = try network(directed: true)
        let undirectedGraph = try network(directed: false)

        // -- Act --
        let directed = try render(directedGraph, positions: positions)
        let undirected = try render(undirectedGraph, positions: positions)

        // -- Assert --
        #expect(directed[4 * (47 * 100 + 70) + 3] > 0)
        #expect(undirected[4 * (47 * 100 + 70) + 3] == 0)
    }

    @Test("A singleton self-loop is visible outside its node")
    func selfLoop() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1)], edges: [GraphEdge(from: 1, to: 1)])

        // -- Act --
        let data = try render(graph, positions: [1: .init(x: 0, y: 0)])

        // -- Assert --
        #expect(data[4 * (36 * 100 + 50) + 3] > 0)
    }

    @Test("Zoom scales self-loop stroke widths with the nodes")
    func zoomedLoop() throws {
        // -- Arrange --
        let graph = try GraphNetwork(
            nodes: [GraphNode(id: 1, color: .clear)],
            edges: [GraphEdge(from: 1, to: 1, width: 2)])

        // -- Act --
        let data = try render(graph, positions: [1: .init(x: 0, y: 0)], zoom: 2)

        // -- Assert --
        #expect(data[4 * (43 * 100 + 50) + 3] > 0)
        #expect(data[4 * (45 * 100 + 50) + 3] == 0)
    }

    @Test("Zoom scales arrowheads beyond the unscaled geometry")
    func zoomedArrow() throws {
        // -- Arrange --
        let nodes = [GraphNode(id: 1, color: .clear), GraphNode(id: 2, color: .clear)]
        let directedGraph = try GraphNetwork(nodes: nodes, edges: [GraphEdge(from: 1, to: 2, directed: true, width: 2)])
        let undirectedGraph = try GraphNetwork(nodes: nodes, edges: [GraphEdge(from: 1, to: 2, width: 2)])
        let positions = [1: PixelPoint(x: -1, y: 0), 2: PixelPoint(x: 1, y: 0)]

        // -- Act --
        let directed = try render(directedGraph, positions: positions, zoom: 2)
        let undirected = try render(undirectedGraph, positions: positions, zoom: 2)

        // -- Assert --
        #expect(directed[4 * (45 * 100 + 90) + 3] > 0)
        #expect(undirected[4 * (45 * 100 + 90) + 3] == 0)
    }

    private func render(_ graph: GraphNetwork<Int>, positions: [Int: PixelPoint], zoom: Double = 1) throws -> Data {
        let renderer = ViewRenderer.make(
            PixelCanvas(pixelsPerCell: .init(width: 1, height: 1)) { context, size in
                let projection = GraphProjection(
                    points: Array(positions.values), size: size, zoom: zoom,
                    offset: .init(x: 0, y: 0), padding: 20)
                GraphRasterizer.draw(
                    graph, positions: positions, selected: nil, context: context, projection: projection)
            }.frame(width: 100, height: 100))
        return try #require(renderer.render(.now).grid?.images.first?.data)
    }

    private func network(directed: Bool) throws -> GraphNetwork<Int> {
        let red = PixelColor(red: 255, green: 0, blue: 0)
        return try GraphNetwork(
            nodes: [GraphNode(id: 1, color: red), GraphNode(id: 2, color: red)],
            edges: [
                GraphEdge(
                    from: 1, to: 2, directed: directed,
                    color: .init(red: 0, green: 255, blue: 0), width: 2)
            ])
    }
}
