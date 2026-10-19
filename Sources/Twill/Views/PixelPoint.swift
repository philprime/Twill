/// A continuous position in a bitmap, with the origin at its top-left corner.
public struct PixelPoint: Sendable, Equatable {
    /// The horizontal coordinate, increasing to the right.
    public var horizontal: Double
    /// The vertical coordinate, increasing downward.
    public var vertical: Double

    /// Creates a pixel-space position.
    public init(x horizontal: Double, y vertical: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}
