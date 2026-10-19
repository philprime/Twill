/// A system monospace font request for pixel-space text.
/// Font sizes are measured in bitmap pixels, not terminal cells or typographic points.
/// Uses the system monospace font when available and a basic-Latin bitmap fallback otherwise.
public struct PixelFont: Sendable, Equatable {
    /// The requested emphasis of a font.
    public enum Weight: Sendable, Equatable {
        /// Normal emphasis.
        case regular
        /// Strong emphasis.
        case bold
    }

    /// The requested font size in pixels.
    public let size: Double
    /// The requested font weight.
    public let weight: Weight

    /// Creates a system monospace font request with a positive, finite pixel size.
    public init(size: Double = 12, weight: Weight = .regular) {
        precondition(size.isFinite && size > 0)
        self.size = size
        self.weight = weight
    }
}
