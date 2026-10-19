import Foundation
import Testing
import Twill

@testable import TwillGraphs

@Suite("Graph rasterization")
struct GraphRasterizerTests {
    @Test("Edges connect colored nodes while unrelated pixels remain transparent")
    func nodesAndEdges() throws {
        // -- Arrange --
        let graph = try network(directed: false)
        let positions = [1: PixelPoint(x: -1, y: 0), 2: PixelPoint(x: 1, y: 0)]
        var context = PixelCanvas.Context(size: .init(width: 100, height: 100))
        let projection = GraphProjection(
            points: Array(positions.values), size: context.size, zoom: 1,
            offset: .init(x: 0, y: 0), padding: 20)

        // -- Act --
        GraphRasterizer.draw(graph, positions: positions, selected: nil, context: &context, projection: projection)
        let data = context.rgbaData

        // -- Assert --
        #expect(Array(data[(4 * (50 * 100 + 20))..<(4 * (50 * 100 + 20) + 4)]) == [255, 0, 0, 255])
        #expect(data[4 * (50 * 100 + 50) + 1] == 255)
        #expect(data[3] == 0)
    }

    @Test("Directed edges add arrowheads outside the line segment")
    func arrows() throws {
        // -- Arrange --
        let positions = [1: PixelPoint(x: -1, y: 0), 2: PixelPoint(x: 1, y: 0)]
        var directed = PixelCanvas.Context(size: .init(width: 100, height: 100))
        var undirected = directed
        let projection = GraphProjection(
            points: Array(positions.values), size: directed.size, zoom: 1,
            offset: .init(x: 0, y: 0), padding: 20)

        // -- Act --
        GraphRasterizer.draw(
            try network(directed: true), positions: positions, selected: nil,
            context: &directed, projection: projection)
        GraphRasterizer.draw(
            try network(directed: false), positions: positions, selected: nil,
            context: &undirected, projection: projection)

        // -- Assert --
        #expect(directed.rgbaData[4 * (47 * 100 + 70) + 3] > 0)
        #expect(undirected.rgbaData[4 * (47 * 100 + 70) + 3] == 0)
    }

    @Test("A singleton self-loop is visible outside its node")
    func selfLoop() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1)], edges: [GraphEdge(from: 1, to: 1)])
        var context = PixelCanvas.Context(size: .init(width: 100, height: 100))
        let projection = GraphProjection(
            points: [.init(x: 0, y: 0)], size: context.size, zoom: 1,
            offset: .init(x: 0, y: 0), padding: 20)

        // -- Act --
        GraphRasterizer.draw(
            graph, positions: [1: .init(x: 0, y: 0)], selected: nil,
            context: &context, projection: projection)

        // -- Assert --
        #expect(context.rgbaData[4 * (36 * 100 + 50) + 3] > 0)
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
