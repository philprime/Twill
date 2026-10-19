import Foundation
import Twill

enum GraphRasterizer {
    static func draw<ID>(
        _ graph: GraphNetwork<ID>, positions: [ID: PixelPoint], selected: ID?,
        context: inout PixelCanvas.Context, projection: GraphProjection
    ) {
        let zoom = projection.zoom
        let points = positions.mapValues { projection.project($0) }
        let nodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        for edge in graph.edges {
            guard let start = points[edge.source], let end = points[edge.target] else { continue }
            if edge.source == edge.target {
                drawLoop(at: start, radius: nodes[edge.source]!.radius * zoom, edge: edge, context: &context)
            } else {
                context.strokeLine(from: start, to: end, color: edge.color, width: edge.width * zoom)
                if edge.directed {
                    let radius = nodes[edge.target]!.radius * zoom
                    arrow(from: start, to: end, radius: radius, edge: edge, context: &context)
                }
            }
        }
        for node in graph.nodes {
            guard let center = points[node.id] else { continue }
            if node.id == selected {
                context.fillCircle(
                    center: center, radius: (node.radius + 3) * zoom,
                    color: PixelColor(red: 255, green: 255, blue: 255))
            }
            context.fillCircle(center: center, radius: node.radius * zoom, color: node.color)
        }
    }

    private static func arrow<ID>(
        from start: PixelPoint, to end: PixelPoint, radius: Double, edge: GraphEdge<ID>,
        context: inout PixelCanvas.Context
    ) {
        let angle = atan2(end.vertical - start.vertical, end.horizontal - start.horizontal)
        let tip = PixelPoint(x: end.horizontal - cos(angle) * radius, y: end.vertical - sin(angle) * radius)
        for side in [-1.0, 1.0] {
            let tail = PixelPoint(
                x: tip.horizontal - cos(angle + side * 0.5) * 7,
                y: tip.vertical - sin(angle + side * 0.5) * 7)
            context.strokeLine(from: tail, to: tip, color: edge.color, width: edge.width)
        }
    }

    private static func drawLoop<ID>(
        at point: PixelPoint, radius: Double, edge: GraphEdge<ID>, context: inout PixelCanvas.Context
    ) {
        let center = PixelPoint(x: point.horizontal, y: point.vertical - radius * 1.8)
        var previous = PixelPoint(x: center.horizontal + radius, y: center.vertical)
        for step in 1...32 {
            let angle = Double(step) * 2 * Double.pi / 32
            let next = PixelPoint(
                x: center.horizontal + cos(angle) * radius, y: center.vertical + sin(angle) * radius)
            context.strokeLine(from: previous, to: next, color: edge.color, width: edge.width)
            previous = next
        }
    }
}
