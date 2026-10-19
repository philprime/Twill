/// A single-line pixel-space label, independent of terminal-cell text layout.
/// System fonts are shaped and rasterized with HarfBuzz. The bitmap fallback supports basic Latin.
public struct PixelText: Sendable, Equatable {
    /// The label's text.
    public let content: String
    /// The requested system monospace font.
    public let font: PixelFont
    /// The glyph color, including its opacity.
    public let color: PixelColor

    /// Creates a label. Control characters become spaces to keep text on one line.
    public init(
        _ content: String, font: PixelFont = PixelFont(),
        color: PixelColor = PixelColor(red: 255, green: 255, blue: 255)
    ) {
        self.content = content
        self.font = font
        self.color = color
    }
}
