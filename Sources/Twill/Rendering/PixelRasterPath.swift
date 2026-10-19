import Foundation

/// Tessellation is local to one drawing operation. Curved contour resolution
/// follows the current transform so magnification does not magnify fixed polygon facets.
struct PixelRasterPath {
    struct Contour {
        let points: [PixelPoint]
        let closed: Bool
    }

    let contours: [Contour]

    init(_ path: Path, transform: PixelTransform = PixelTransform(), resolutionScale: Double = 1) {
        var result: [Contour] = []
        var points: [PixelPoint] = []
        for element in path.elements {
            switch element {
            case .move(let point):
                if points.count > 1 { result.append(Contour(points: points, closed: false)) }
                points = [point]
            case .line(let point):
                points.append(point)
            case .close:
                if points.count > 1 { result.append(Contour(points: points, closed: true)) }
                points = points.first.map { [$0] } ?? []
            case .ellipse(let rectangle):
                if points.count > 1 { result.append(Contour(points: points, closed: false)) }
                result.append(Contour(points: Self.ellipse(rectangle, scale: resolutionScale), closed: true))
                points = []
            }
        }
        if points.count > 1 { result.append(Contour(points: points, closed: false)) }
        contours = result.map { Contour(points: $0.points.map { transform.apply($0) }, closed: $0.closed) }
    }

    private init(contours: [Contour]) {
        self.contours = contours
    }

    func applying(_ transform: PixelTransform) -> Self {
        Self(contours: contours.map { Contour(points: $0.points.map { transform.apply($0) }, closed: $0.closed) })
    }

    var bounds: PixelPathBounds? {
        let points = contours.flatMap(\.points)
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce(
            PixelPathBounds(
                minimumX: first.horizontal, minimumY: first.vertical,
                maximumX: first.horizontal, maximumY: first.vertical)
        ) { bounds, point in
            PixelPathBounds(
                minimumX: min(bounds.minimumX, point.horizontal),
                minimumY: min(bounds.minimumY, point.vertical),
                maximumX: max(bounds.maximumX, point.horizontal),
                maximumY: max(bounds.maximumY, point.vertical))
        }
    }

    func contains(_ point: PixelPoint) -> Bool {
        var winding = 0
        for contour in contours where contour.points.count > 2 {
            for index in contour.points.indices {
                let start = contour.points[index]
                let end = contour.points[(index + 1) % contour.points.count]
                let cross =
                    (end.horizontal - start.horizontal) * (point.vertical - start.vertical)
                    - (point.horizontal - start.horizontal) * (end.vertical - start.vertical)
                if start.vertical <= point.vertical && end.vertical > point.vertical && cross > 0 { winding += 1 }
                if start.vertical > point.vertical && end.vertical <= point.vertical && cross < 0 { winding -= 1 }
            }
        }
        return winding != 0
    }

    func containsStroke(_ point: PixelPoint, radius: Double) -> Bool {
        for contour in contours {
            let count = contour.closed ? contour.points.count : contour.points.count - 1
            for index in 0..<count {
                let start = contour.points[index]
                let end = contour.points[(index + 1) % contour.points.count]
                if Self.distance(point, from: start, to: end) <= radius { return true }
            }
        }
        return false
    }

    private static func distance(_ point: PixelPoint, from start: PixelPoint, to end: PixelPoint) -> Double {
        let deltaX = end.horizontal - start.horizontal
        let deltaY = end.vertical - start.vertical
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        let parameter =
            lengthSquared > 0
            ? min(
                1,
                max(
                    0,
                    ((point.horizontal - start.horizontal) * deltaX
                        + (point.vertical - start.vertical) * deltaY) / lengthSquared)) : 0
        return hypot(
            point.horizontal - start.horizontal - parameter * deltaX,
            point.vertical - start.vertical - parameter * deltaY)
    }

    private static func ellipse(_ rectangle: PixelRect, scale: Double) -> [PixelPoint] {
        let horizontalRadius = rectangle.width / 2
        let verticalRadius = rectangle.height / 2
        let pixelRadius = max(horizontalRadius, verticalRadius) * scale
        let maximumChordError = 0.125
        let segments = max(12, Int(ceil(Double.pi * sqrt(max(1, pixelRadius) / maximumChordError))))
        return (0..<segments).map { index in
            let angle = Double(index) * 2 * Double.pi / Double(segments)
            return PixelPoint(
                x: rectangle.origin.horizontal + horizontalRadius * (1 + cos(angle)),
                y: rectangle.origin.vertical + verticalRadius * (1 + sin(angle)))
        }
    }
}
