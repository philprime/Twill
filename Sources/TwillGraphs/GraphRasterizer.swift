import Foundation
import Twill

@MainActor
enum GraphRasterizer {
    static let selectionRingWidth = 3.0

    static func draw<ID>(
        _ graph: GraphNetwork<ID>, positions: [ID: PixelPoint], selected: ID?,
        context: PixelCanvas.Context, projection: GraphProjection, labels: GraphLabelVisibility = .hidden
    ) {
        let zoom = projection.zoom
        let points = positions.mapValues { projection.project($0) }
        let nodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        for edge in graph.edges {
            guard let start = points[edge.source], let end = points[edge.target] else { continue }
            if edge.source == edge.target {
                drawLoop(at: start, radius: nodes[edge.source]!.radius * zoom, edge: edge, zoom: zoom, context: context)
            } else {
                let line = Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                context.stroke(line, with: edge.color, lineWidth: edge.width * zoom)
                if edge.directed {
                    let radius = nodes[edge.target]!.radius * zoom
                    context.stroke(
                        arrow(from: start, to: end, radius: radius, length: 7 * zoom),
                        with: edge.color, lineWidth: edge.width * zoom)
                }
            }
        }
        for node in graph.nodes {
            guard let center = points[node.id] else { continue }
            if node.id == selected {
                context.fill(
                    circle(at: center, radius: (node.radius + selectionRingWidth) * zoom),
                    with: PixelColor(red: 255, green: 255, blue: 255))
            }
            context.fill(circle(at: center, radius: node.radius * zoom), with: node.color)
        }
        if labels == .automatic {
            let placements = GraphLabelLayout(measure: context.measure).place(
                graph, points: points, selected: selected, zoom: zoom, size: projection.size)
            for label in placements.reversed() {
                context.draw(
                    label.text,
                    at: PixelPoint(
                        x: label.bounds.origin.horizontal + label.bounds.width / 2,
                        y: label.bounds.origin.vertical),
                    anchor: .top)
            }
        }
    }

    private static func arrow(
        from start: PixelPoint, to end: PixelPoint, radius: Double, length: Double
    ) -> Path {
        let angle = atan2(end.vertical - start.vertical, end.horizontal - start.horizontal)
        let tip = PixelPoint(x: end.horizontal - cos(angle) * radius, y: end.vertical - sin(angle) * radius)
        return Path { path in
            for side in [-1.0, 1.0] {
                let tail = PixelPoint(
                    x: tip.horizontal - cos(angle + side * 0.5) * length,
                    y: tip.vertical - sin(angle + side * 0.5) * length)
                path.move(to: tail)
                path.addLine(to: tip)
            }
        }
    }

    private static func drawLoop<ID>(
        at point: PixelPoint, radius: Double, edge: GraphEdge<ID>, zoom: Double, context: PixelCanvas.Context
    ) {
        let center = PixelPoint(x: point.horizontal, y: point.vertical - radius * 1.8)
        context.stroke(circle(at: center, radius: radius), with: edge.color, lineWidth: edge.width * zoom)
    }

    private static func circle(at center: PixelPoint, radius: Double) -> Path {
        Path(
            ellipseIn: PixelRect(
                x: center.horizontal - radius, y: center.vertical - radius,
                width: radius * 2, height: radius * 2))
    }
}
