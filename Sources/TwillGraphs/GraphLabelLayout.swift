import Twill

/// Places labels in screen pixels so camera zoom never scales their text.
/// Graph insertion order breaks priority ties, keeping repeated frames stable.
@MainActor
struct GraphLabelLayout {
    private let measure: @MainActor (PixelText) -> PixelTextMetrics

    init(measure: @escaping @MainActor (PixelText) -> PixelTextMetrics) {
        self.measure = measure
    }

    private static let fontSize = 12.0
    private static let nodeGap = 4.0
    private static let labelGap = 2.0
    private static let minimumOverviewDegree = 3
    private static let labelColor = PixelColor(red: 163, green: 170, blue: 184)
    private static let selectedColor = PixelColor(red: 255, green: 255, blue: 255)

    private struct ProjectedNode<ID: Hashable & Sendable> {
        let node: GraphNode<ID>
        let point: PixelPoint
        let radius: Double
        let bounds: PixelRect
        let selected: Bool
        let degree: Int
        let order: Int
    }

    func place<ID>(
        _ graph: GraphNetwork<ID>, points: [ID: PixelPoint], selected: ID?, zoom: Double,
        size: PixelSize
    ) -> [GraphLabelPlacement<ID>] {
        guard size.width > 0, size.height > 0 else { return [] }
        let viewport = PixelRect(x: 0, y: 0, width: Double(size.width), height: Double(size.height))
        let nodes = Self.projectedNodes(graph, points: points, selected: selected, zoom: zoom)
            .filter { Self.intersects($0.bounds, viewport) }
        let prioritized = nodes.sorted { left, right in
            if left.selected != right.selected { return left.selected }
            if left.degree != right.degree { return left.degree > right.degree }
            return left.order < right.order
        }
        var result: [GraphLabelPlacement<ID>] = []
        var occupied: [PixelRect] = []
        for item in prioritized where item.selected || zoom >= 1 || item.degree >= Self.minimumOverviewDegree {
            let text = PixelText(
                item.node.label, font: PixelFont(size: Self.fontSize, weight: item.selected ? .bold : .regular),
                color: item.selected ? Self.selectedColor : Self.labelColor)
            let metrics = measure(text)
            guard metrics.width > 0, metrics.height > 0 else { continue }
            let candidates = Self.candidates(for: item, metrics: metrics, viewport: viewport)
            let fitting = candidates.first { candidate in
                Self.fits(candidate, inside: viewport)
                    && !nodes.contains { Self.intersects(candidate, $0.bounds) }
                    && !occupied.contains { Self.intersects(candidate, $0) }
            }
            // Selection remains identifiable even when the viewport cannot fit a collision-free label.
            guard let bounds = fitting ?? (item.selected ? candidates.first : nil) else { continue }
            result.append(GraphLabelPlacement(nodeID: item.node.id, text: text, bounds: bounds))
            occupied.append(
                PixelRect(
                    x: bounds.origin.horizontal - Self.labelGap, y: bounds.origin.vertical - Self.labelGap,
                    width: bounds.width + Self.labelGap * 2, height: bounds.height + Self.labelGap * 2))
        }
        return result
    }

    private static func projectedNodes<ID>(
        _ graph: GraphNetwork<ID>, points: [ID: PixelPoint], selected: ID?, zoom: Double
    ) -> [ProjectedNode<ID>] {
        var degrees: [ID: Int] = [:]
        for edge in graph.edges {
            degrees[edge.source, default: 0] += 1
            if edge.target != edge.source { degrees[edge.target, default: 0] += 1 }
        }
        return graph.nodes.enumerated().compactMap { order, node in
            guard let point = points[node.id] else { return nil }
            let isSelected = node.id == selected
            let radius = (node.radius + (isSelected ? GraphRasterizer.selectionRingWidth : 0)) * zoom
            return ProjectedNode(
                node: node, point: point, radius: radius,
                bounds: PixelRect(
                    x: point.horizontal - radius, y: point.vertical - radius, width: radius * 2, height: radius * 2),
                selected: isSelected, degree: degrees[node.id, default: 0], order: order)
        }
    }

    private static func candidates<ID>(
        for item: ProjectedNode<ID>, metrics: PixelTextMetrics, viewport: PixelRect
    ) -> [PixelRect] {
        let point = item.point
        let distance = item.radius + nodeGap
        let origins = [
            PixelPoint(x: point.horizontal - metrics.width / 2, y: point.vertical + distance),
            PixelPoint(x: point.horizontal - metrics.width / 2, y: point.vertical - distance - metrics.height),
            PixelPoint(x: point.horizontal + distance, y: point.vertical - metrics.height / 2),
            PixelPoint(x: point.horizontal - distance - metrics.width, y: point.vertical - metrics.height / 2),
        ]
        return origins.map { origin in
            PixelRect(
                x: max(0, min(viewport.width - metrics.width, origin.horizontal)),
                y: max(0, min(viewport.height - metrics.height, origin.vertical)),
                width: metrics.width, height: metrics.height)
        }
    }

    private static func fits(_ rectangle: PixelRect, inside viewport: PixelRect) -> Bool {
        rectangle.origin.horizontal >= 0 && rectangle.origin.vertical >= 0
            && rectangle.origin.horizontal + rectangle.width <= viewport.width
            && rectangle.origin.vertical + rectangle.height <= viewport.height
    }

    private static func intersects(_ left: PixelRect, _ right: PixelRect) -> Bool {
        left.origin.horizontal < right.origin.horizontal + right.width
            && left.origin.horizontal + left.width > right.origin.horizontal
            && left.origin.vertical < right.origin.vertical + right.height
            && left.origin.vertical + left.height > right.origin.vertical
    }
}
