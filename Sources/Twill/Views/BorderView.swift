/// Draws a terminal border around the measured content.
public struct BorderView<Content: View, BorderStyle: Style>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    let content: Content
    let border: Border
    let color: BorderStyle
}

extension View {
    /// Adds a one-cell border around the content using the supplied color style.
    public func border<S: Style>(_ border: Border, color: S) -> BorderView<Self, S> {
        BorderView(content: self, border: border, color: color)
    }
}

extension BorderView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .border(content, glyphs: border.glyphs, color: color)
    }
}
