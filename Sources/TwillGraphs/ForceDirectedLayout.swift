import Foundation
import Twill

/// A deterministic, bounded Fruchterman-Reingold layout for small networks.
/// Pairwise repulsion is quadratic in node count. This is not a Barnes-Hut solver.
/// Compute positions when graph data changes, not from a view body or drawing callback.
public struct ForceDirectedLayout: Sendable {
    /// The preferred separation in graph-space units.
    public let springLength: Double

    /// Creates a layout with a positive finite preferred separation.
    public init(springLength: Double = 80) {
        precondition(springLength.isFinite && springLength > 0)
        self.springLength = springLength
    }

    /// Runs a fixed number of cooling iterations without timers or wall-clock input.
    /// Initial positions preserve the starting geometry of surviving nodes. Missing
    /// positions use deterministic spiral seeds, and obsolete identities are discarded.
    public func positions<ID>(
        for graph: GraphNetwork<ID>, iterations: Int = 150, initial: [ID: PixelPoint] = [:]
    ) -> [ID: PixelPoint] {
        precondition(iterations >= 0)
        guard !graph.nodes.isEmpty else { return [:] }
        var points = graph.nodes.enumerated().map { index, node in
            initial[node.id] ?? seed(index: index, count: graph.nodes.count)
        }
        precondition(points.allSatisfy { $0.horizontal.isFinite && $0.vertical.isFinite })
        let indices = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element.id, $0.offset) })
        let connections = graph.edges.compactMap { edge -> (Int, Int)? in
            guard let source = indices[edge.source], let target = indices[edge.target], source != target else {
                return nil
            }
            return (source, target)
        }
        for iteration in 0..<iterations {
            var forces = Array(repeating: PixelPoint(x: 0, y: 0), count: points.count)
            repel(points, forces: &forces)
            for (source, target) in connections {
                let deltaX = points[target].horizontal - points[source].horizontal
                let deltaY = points[target].vertical - points[source].vertical
                let distance = hypot(deltaX, deltaY)
                let strength = distance / springLength
                forces[source].horizontal += deltaX * strength
                forces[source].vertical += deltaY * strength
                forces[target].horizontal -= deltaX * strength
                forces[target].vertical -= deltaY * strength
            }
            let temperature = springLength * 0.1 * (1 - Double(iteration) / Double(iterations))
            for index in points.indices {
                // Gentle gravity keeps disconnected components from drifting without bound.
                let deltaX = forces[index].horizontal - points[index].horizontal * 0.05
                let deltaY = forces[index].vertical - points[index].vertical * 0.05
                let distance = max(0.001, hypot(deltaX, deltaY))
                let step = min(temperature, distance) / distance
                points[index].horizontal += deltaX * step
                points[index].vertical += deltaY * step
            }
        }
        return Dictionary(uniqueKeysWithValues: zip(graph.nodes.map(\.id), points))
    }

    private func seed(index: Int, count: Int) -> PixelPoint {
        guard count > 1 else { return PixelPoint(x: 0, y: 0) }
        let angle = Double(index) * 2.399963229728653
        let radius = springLength * sqrt(Double(index + 1))
        return PixelPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }

    private func repel(_ points: [PixelPoint], forces: inout [PixelPoint]) {
        for source in points.indices {
            for target in (source + 1)..<points.count {
                var deltaX = points[source].horizontal - points[target].horizontal
                var deltaY = points[source].vertical - points[target].vertical
                if deltaX == 0 && deltaY == 0 {
                    // Stable tie-breaking avoids a random jitter dependency and zero-distance division.
                    deltaX = cos(Double(source + target) * 2.399963229728653)
                    deltaY = sin(Double(source + target) * 2.399963229728653)
                }
                let distance = max(1, hypot(deltaX, deltaY))
                let strength = springLength * springLength / (distance * distance)
                forces[source].horizontal += deltaX * strength
                forces[source].vertical += deltaY * strength
                forces[target].horizontal -= deltaX * strength
                forces[target].vertical -= deltaY * strength
            }
        }
    }
}
