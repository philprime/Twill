/// Raster bounds are clipped to the surface before any integer conversion.
struct PixelPathBounds {
    var minimumX: Double
    var minimumY: Double
    var maximumX: Double
    var maximumY: Double

    func expanded(by margin: Double) -> Self {
        Self(
            minimumX: minimumX - margin, minimumY: minimumY - margin,
            maximumX: maximumX + margin, maximumY: maximumY + margin)
    }

    func intersection(_ other: Self) -> Self {
        Self(
            minimumX: max(minimumX, other.minimumX), minimumY: max(minimumY, other.minimumY),
            maximumX: min(maximumX, other.maximumX), maximumY: min(maximumY, other.maximumY))
    }
}
