import Foundation
import Testing

@testable import Twill
@testable import TwillGraphs

@Suite("Graph rendering")
@MainActor
struct GraphViewTests {
    private final class Selection {
        var value: String?
        var binding: Binding<String?>?
    }

    private struct InteractiveGraph: View {
        let graph: GraphNetwork<String>
        let capture: (Binding<String?>) -> Void
        @State private var selected: String?

        var body: some View {
            capture($selected)
            return GraphView(
                graph, positions: ["a": .init(x: -20, y: 0), "b": .init(x: 20, y: 0)],
                selection: $selected
            ).frame(width: 20, height: 8)
        }
    }

    @Test("Graph rendering produces RGBA edges and nodes without scheduling work")
    func drawing() throws {
        // -- Arrange --
        let graph = try GraphNetwork(
            nodes: [GraphNode(id: "a", label: "Alpha"), GraphNode(id: "b", label: "Beta")],
            edges: [GraphEdge(from: "a", to: "b", directed: true)])
        let positions = ["a": PixelPoint(x: -20, y: 0), "b": PixelPoint(x: 20, y: 0)]
        let renderer = ViewRenderer.make(GraphView(graph, positions: positions).frame(width: 20, height: 8))

        // -- Act --
        let frame = renderer.render(.now)
        let image = try #require(frame.grid?.images.first)

        // -- Assert --
        #expect(image.format == .rgba(width: 160, height: 112))
        #expect(image.data.contains { $0 != 0 })
        #expect(frame.grid?.snapshotText.contains("Alpha") == true)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Arrow selection updates the binding while zoom changes the rendered bitmap")
    func interaction() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: "a"), GraphNode(id: "b")], edges: [])
        let selection = Selection()
        let renderer = ViewRenderer.make(InteractiveGraph(graph: graph) { selection.binding = $0 })
        let first = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.arrowRight)
        let selected = renderer.render(.now)
        let zoomed = renderer.handle(.character("+"))
        let enlarged = renderer.render(.now)

        // -- Assert --
        #expect(handled == true)
        #expect(selection.binding?.wrappedValue == "b")
        #expect(selected.grid?.images != first.grid?.images)
        #expect(zoomed == true)
        #expect(enlarged.grid?.images != selected.grid?.images)
        #expect(renderer.handle(.tab) == false)
    }

    @Test("A missing selected node falls back visually without rewriting the binding")
    func staleSelection() throws {
        // -- Arrange --
        let graph = try GraphNetwork(nodes: [GraphNode(id: "a", label: "Alpha")], edges: [])
        let selection = Selection()
        selection.value = "removed"
        let renderer = ViewRenderer.make(
            GraphView(
                graph, positions: ["a": .init(x: 0, y: 0)],
                selection: Binding(get: { selection.value }, set: { selection.value = $0 })
            )
            .frame(width: 20, height: 8))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText.contains("Alpha") == true)
        #expect(selection.value == "removed")
    }

    @Test("Empty graphs render without inventing nodes or trapping navigation")
    func empty() throws {
        // -- Arrange --
        let graph = try GraphNetwork<String>(nodes: [], edges: [])
        let renderer = ViewRenderer.make(GraphView(graph, positions: [:]).frame(width: 10, height: 4))

        // -- Act --
        let frame = renderer.render(.now)
        let key = renderer.handle(.arrowRight)

        // -- Assert --
        #expect(frame.nextUpdate == nil)
        #expect(frame.grid?.snapshotText.contains("No nodes") == true)
        #expect(key == false)
    }
}

extension CellGrid {
    fileprivate var snapshotText: String {
        (0..<size.height).map { row in
            (0..<size.width).reduce(into: "") { text, column in
                switch self[column, row] {
                case .blank: text += " "
                case .glyph(let character, _): text.append(character)
                case .continuation: break
                }
            }
        }.joined(separator: "\n")
    }
}
