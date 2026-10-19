import Twill

/// A keyboard-selectable network rendered through PixelCanvas, with the selected
/// node's label in a terminal-text caption. Requires Kitty graphics support.
/// Arrows select in insertion order, +/- zoom, WASD pan, and 0 fits the graph.
/// Tab remains available to leave the graph. Layout is supplied, never simulated while drawing.
public struct GraphView<ID: Hashable & Sendable>: View {
    private let graph: GraphNetwork<ID>
    private let positions: [ID: PixelPoint]
    private let selection: Binding<ID?>?
    @State private var localSelection: ID?
    @State private var zoom: Double = 1
    @State private var offset = PixelPoint(x: 0, y: 0)

    /// Creates a graph with positions for every node. Use ForceDirectedLayout to
    /// compute positions, optionally seeding it with a previous layout after mutations.
    /// Without a binding, keyboard selection is retained in mounted local state.
    public init(_ graph: GraphNetwork<ID>, positions: [ID: PixelPoint], selection: Binding<ID?>? = nil) {
        precondition(graph.nodes.allSatisfy { positions[$0.id] != nil })
        precondition(positions.values.allSatisfy { $0.horizontal.isFinite && $0.vertical.isFinite })
        self.graph = graph
        self.positions = positions
        self.selection = selection
    }

    private var selectedIndex: Int? {
        let selected = selection?.wrappedValue ?? localSelection
        return graph.nodes.firstIndex { $0.id == selected } ?? graph.nodes.indices.first
    }

    /// The bitmap and selection caption, presented as one keyboard focus target.
    public var body: some View {
        let selected = selectedIndex.map { graph.nodes[$0] }
        return VStack(alignment: .leading, spacing: 0) {
            PixelCanvas { context, size in
                let projection = GraphProjection(
                    points: graph.nodes.compactMap { positions[$0.id] }, size: size, zoom: zoom, offset: offset,
                    padding: (graph.nodes.map(\.radius).max() ?? 5) * 3 + 4)
                GraphRasterizer.draw(
                    graph, positions: positions, selected: selected?.id,
                    context: context, projection: projection)
            }
            Text(selected?.label ?? "No nodes")
        }
        .focusable()
        .onKeyPress { handle($0) }
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        guard key.modifiers.isEmpty else { return .ignored }
        if [.arrowLeft, .arrowUp, .arrowRight, .arrowDown].contains(key) {
            guard let index = selectedIndex else { return .ignored }
            let forward = key == .arrowRight || key == .arrowDown
            let next = min(graph.nodes.count - 1, max(0, index + (forward ? 1 : -1)))
            let id = graph.nodes[next].id
            if let selection { selection.wrappedValue = id } else { localSelection = id }
            return .handled
        }
        return handleViewport(key)
    }

    private func handleViewport(_ key: KeyEvent) -> KeyPressResult {
        switch key.key {
        case .character("+"), .character("="): zoom = min(16, zoom * 1.25)
        case .character("-"): zoom = max(0.125, zoom / 1.25)
        case .character("a"): offset.horizontal += 16
        case .character("d"): offset.horizontal -= 16
        case .character("w"): offset.vertical += 16
        case .character("s"): offset.vertical -= 16
        case .character("0"):
            zoom = 1
            offset = PixelPoint(x: 0, y: 0)
        default: return .ignored
        }
        return .handled
    }
}
