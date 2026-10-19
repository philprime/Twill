/// Untransformed text layout measurements in continuous pixel coordinates.
/// Layout bounds include spacing and can differ from the visible glyph bounds.
public struct PixelTextMetrics: Sendable, Equatable {
    /// The horizontal advance of the label.
    public let width: Double
    /// The height of the label's layout box.
    public let height: Double
    /// The baseline's downward distance from the top of the layout box.
    public let firstBaseline: Double
}
