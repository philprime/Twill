/// Conservative device-space row bounds for a round-capped stroke. Coverage
/// remains evaluated in local coordinates, including under nonuniform transforms.
struct PixelStrokeBounds {
    private struct Segment {
        let start: PixelPoint
        let end: PixelPoint

        init(start: PixelPoint, end: PixelPoint) {
            self.start = start.vertical <= end.vertical ? start : end
            self.end = start.vertical <= end.vertical ? end : start
        }

        func horizontalRange(lowerY: Double, upperY: Double, radius: Double) -> ClosedRange<Double>? {
            guard end.vertical >= lowerY, start.vertical <= upperY else { return nil }
            let height = end.vertical - start.vertical
            let first = height > 0 ? max(0, (lowerY - start.vertical) / height) : 0
            let last = height > 0 ? min(1, (upperY - start.vertical) / height) : 1
            let firstX = start.horizontal * (1 - first) + end.horizontal * first
            let lastX = start.horizontal * (1 - last) + end.horizontal * last
            return (min(firstX, lastX) - radius)...(max(firstX, lastX) + radius)
        }
    }

    private let segments: [Segment]
    private let radius: Double

    init(path: PixelRasterPath, radius: Double) {
        self.radius = radius
        segments = path.contours.flatMap { contour in
            let count = contour.closed ? contour.points.count : contour.points.count - 1
            return (0..<count).map { index in
                Segment(start: contour.points[index], end: contour.points[(index + 1) % contour.points.count])
            }
        }
    }

    func horizontalRange(for row: Int) -> ClosedRange<Double>? {
        // A transformed local round cap fits inside the supplied device radius.
        // Expand the row vertically before clipping centerlines, then horizontally
        // to include every sample that can be covered by the stroke.
        let lowerY = Double(row) - radius
        let upperY = Double(row + 1) + radius
        var left = Double.infinity
        var right = -Double.infinity
        for segment in segments {
            guard let range = segment.horizontalRange(lowerY: lowerY, upperY: upperY, radius: radius) else { continue }
            left = min(left, range.lowerBound)
            right = max(right, range.upperBound)
        }
        return left <= right ? left...right : nil
    }
}
