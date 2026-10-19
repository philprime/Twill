import Foundation
import Testing
import Twill

@testable import TwillGraphs

@Suite("Force-directed layout")
struct ForceDirectedLayoutTests {
    @Test("Layout is deterministic, finite, and separates coincident disconnected nodes")
    func separation() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1), GraphNode(id: 2), GraphNode(id: 3)], edges: [])
        let initial = [1: PixelPoint(x: 0, y: 0), 2: PixelPoint(x: 0, y: 0)]
        let layout = ForceDirectedLayout()

        // -- Act --
        let first = layout.positions(for: graph, initial: initial)
        let repeated = layout.positions(for: graph, initial: initial)

        // -- Assert --
        #expect(first == repeated)
        #expect(first.count == 3)
        #expect(first[1] != first[2])
        #expect(first.values.allSatisfy { $0.horizontal.isFinite && $0.vertical.isFinite })
    }

    @Test("Springs pull connected nodes together and zero iterations preserve known positions")
    func attraction() throws {
        // -- Arrange --
        let graph = try GraphNetwork(
            nodes: [GraphNode(id: 1), GraphNode(id: 2)],
            edges: [GraphEdge(from: 1, to: 2)])
        let initial = [1: PixelPoint(x: -200, y: 0), 2: PixelPoint(x: 200, y: 0)]
        let layout = ForceDirectedLayout()

        // -- Act --
        let unchanged = layout.positions(for: graph, iterations: 0, initial: initial)
        let settled = layout.positions(for: graph, initial: initial)
        let left = try #require(settled[1])
        let right = try #require(settled[2])

        // -- Assert --
        #expect(unchanged == initial)
        #expect(hypot(right.horizontal - left.horizontal, right.vertical - left.vertical) < 400)
    }

    @Test("Empty and singleton networks have well-defined layouts")
    func smallGraphs() throws {
        // -- Arrange --
        let empty = try GraphNetwork<Int>(nodes: [], edges: [])
        let single = try GraphNetwork(nodes: [GraphNode(id: 1)], edges: [])

        // -- Act --
        let layout = ForceDirectedLayout()
        let emptyPositions = layout.positions(for: empty)
        let singlePositions = layout.positions(for: single)

        // -- Assert --
        #expect(emptyPositions.isEmpty)
        #expect(singlePositions == [1: PixelPoint(x: 0, y: 0)])
    }
}
