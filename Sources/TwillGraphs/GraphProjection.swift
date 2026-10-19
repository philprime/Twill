import Twill

/// Fits graph coordinates into a bitmap while keeping pan offsets in screen pixels.
struct GraphProjection {
    let center: PixelPoint
    let origin: PixelPoint
    let scale: Double
    let zoom: Double
    let size: PixelSize

    init(points: [PixelPoint], size: PixelSize, zoom: Double, offset: PixelPoint, padding: Double) {
        self.zoom = zoom
        self.size = size
        let minimumX = points.map(\.horizontal).min() ?? 0
        let maximumX = points.map(\.horizontal).max() ?? 0
        let minimumY = points.map(\.vertical).min() ?? 0
        let maximumY = points.map(\.vertical).max() ?? 0
        center = PixelPoint(x: (minimumX + maximumX) / 2, y: (minimumY + maximumY) / 2)
        origin = PixelPoint(
            x: Double(size.width) / 2 + offset.horizontal, y: Double(size.height) / 2 + offset.vertical)
        let availableWidth = max(1, Double(size.width) - 2 * padding)
        let availableHeight = max(1, Double(size.height) - 2 * padding)
        scale =
            min(
                availableWidth / max(1, maximumX - minimumX),
                availableHeight / max(1, maximumY - minimumY)) * zoom
    }

    func project(_ point: PixelPoint) -> PixelPoint {
        PixelPoint(
            x: origin.horizontal + (point.horizontal - center.horizontal) * scale,
            y: origin.vertical + (point.vertical - center.vertical) * scale)
    }
}
