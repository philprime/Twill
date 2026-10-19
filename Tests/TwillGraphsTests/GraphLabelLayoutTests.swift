import Testing

@testable import Twill
@testable import TwillGraphs

@Suite("Graph label placement")
@MainActor
struct GraphLabelLayoutTests {
    @Test("Labels prefer a centered position below their node")
    func belowNode() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1, label: "Alpha")])

        // -- Act --
        let labels = GraphLabelLayout(measure: measure).place(
            graph, points: [1: .init(x: 50, y: 40)], selected: nil, zoom: 1,
            size: .init(width: 100, height: 100))

        // -- Assert --
        let label = try #require(labels.first)
        #expect(label.nodeID == 1)
        #expect(label.text.content == "Alpha")
        #expect(label.bounds == PixelRect(x: 35, y: 49, width: 30, height: 12))
    }

    @Test("The selected node wins when there is only room for one label")
    func selectedPriority() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1), GraphNode(id: 2)])
        let points = [1: PixelPoint(x: 40, y: 20), 2: PixelPoint(x: 40, y: 20)]

        // -- Act --
        let labels = GraphLabelLayout(measure: { _ in PixelTextMetrics(width: 70, height: 16, firstBaseline: 12) })
            .place(
                graph, points: points, selected: 2, zoom: 1, size: .init(width: 80, height: 50))

        // -- Assert --
        #expect(labels.map(\.nodeID) == [2])
        #expect(labels.first?.text.font.weight == .bold)
    }

    @Test("Overview labels favor connected nodes rather than isolated nodes")
    func overview() throws {
        // -- Arrange --
        let graph = try hubGraph()
        let points = [
            1: PixelPoint(x: 30, y: 30), 2: PixelPoint(x: 130, y: 30),
            3: PixelPoint(x: 30, y: 130), 4: PixelPoint(x: 130, y: 130),
        ]

        // -- Act --
        let overview = GraphLabelLayout(measure: measure).place(
            graph, points: points, selected: 1, zoom: 0.5, size: .init(width: 200, height: 200))
        let detailed = GraphLabelLayout(measure: measure).place(
            graph, points: points, selected: 1, zoom: 1, size: .init(width: 200, height: 200))

        // -- Assert --
        #expect(overview.map(\.nodeID) == [1, 2])
        #expect(Set(detailed.map(\.nodeID)) == [1, 2, 3, 4])
    }

    @Test("Higher-degree nodes win collisions before insertion order")
    func degreePriority() throws {
        // -- Arrange --
        let graph = try hubGraph()
        let points = [
            1: PixelPoint(x: 40, y: 20), 2: PixelPoint(x: 40, y: 20),
            3: PixelPoint(x: -100, y: -100), 4: PixelPoint(x: -100, y: -100),
        ]

        // -- Act --
        let labels = GraphLabelLayout(measure: { _ in PixelTextMetrics(width: 70, height: 16, firstBaseline: 12) })
            .place(
                graph, points: points, selected: nil, zoom: 1, size: .init(width: 80, height: 50))

        // -- Assert --
        #expect(labels.map(\.nodeID) == [2])
    }

    @Test("Labels move above a node when the preferred position would cover another node")
    func avoidNodes() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1), GraphNode(id: 2)])
        let points = [1: PixelPoint(x: 50, y: 50), 2: PixelPoint(x: 50, y: 75)]

        // -- Act --
        let labels = GraphLabelLayout(measure: measure).place(
            graph, points: points, selected: nil, zoom: 1,
            size: .init(width: 100, height: 100))

        // -- Assert --
        #expect(labels.first?.nodeID == 1)
        #expect(labels.first?.bounds == PixelRect(x: 35, y: 29, width: 30, height: 12))
        #expect(labels.count == 2)
    }

    @Test("Zoom preserves text size while pan moves labels with their nodes")
    func viewportChanges() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1)])
        let size = PixelSize(width: 200, height: 200)
        let layout = GraphLabelLayout(measure: measure)

        // -- Act --
        let initial = try #require(
            layout.place(
                graph, points: [1: .init(x: 100, y: 100)], selected: nil, zoom: 1, size: size
            ).first)
        let zoomed = try #require(
            layout.place(
                graph, points: [1: .init(x: 100, y: 100)], selected: nil, zoom: 2, size: size
            ).first)
        let panned = try #require(
            layout.place(
                graph, points: [1: .init(x: 116, y: 92)], selected: nil, zoom: 1, size: size
            ).first)

        // -- Assert --
        #expect(initial.text.font == zoomed.text.font)
        #expect(initial.bounds.width == zoomed.bounds.width)
        #expect(initial.bounds.height == zoomed.bounds.height)
        #expect(zoomed.bounds.origin.vertical - initial.bounds.origin.vertical == 5)
        #expect(panned.bounds.origin.horizontal - initial.bounds.origin.horizontal == 16)
        #expect(panned.bounds.origin.vertical - initial.bounds.origin.vertical == -8)
    }

    @Test("Edge labels stay inside the viewport and offscreen nodes have no floating labels")
    func viewportBounds() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: 1), GraphNode(id: 2)])

        // -- Act --
        let labels = GraphLabelLayout(measure: measure).place(
            graph, points: [1: .init(x: 3, y: 3), 2: .init(x: -100, y: -100)],
            selected: 1, zoom: 1, size: .init(width: 100, height: 100))

        // -- Assert --
        #expect(labels.map(\.nodeID) == [1])
        #expect(labels.first?.bounds.origin.horizontal == 0)
        #expect(labels.first?.bounds.origin.vertical == 15)
    }

    private func measure(_: PixelText) -> PixelTextMetrics {
        PixelTextMetrics(width: 30, height: 12, firstBaseline: 9)
    }

    private func hubGraph() throws -> GraphNetwork<Int> {
        try GraphNetwork(
            nodes: [1, 2, 3, 4].map { GraphNode(id: $0) },
            edges: [GraphEdge(from: 2, to: 1), GraphEdge(from: 2, to: 3), GraphEdge(from: 2, to: 4)])
    }
}
