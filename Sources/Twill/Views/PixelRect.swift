/// A finite, axis-aligned rectangle in continuous pixel coordinates.
public struct PixelRect: Sendable, Equatable {
    /// The top-left corner.
    public let origin: PixelPoint
    /// The nonnegative horizontal extent.
    public let width: Double
    /// The nonnegative vertical extent.
    public let height: Double

    /// Creates a rectangle. Empty rectangles contribute no filled area.
    public init(x horizontal: Double, y vertical: Double, width: Double, height: Double) {
        precondition(horizontal.isFinite && vertical.isFinite)
        precondition(width.isFinite && height.isFinite && width >= 0 && height >= 0)
        precondition((horizontal + width).isFinite && (vertical + height).isFinite)
        origin = PixelPoint(x: horizontal, y: vertical)
        self.width = width
        self.height = height
    }
}
