/// Draws a terminal border around the measured content.
public struct BorderView<Content: View, BorderStyle: Style>: View {
    public typealias Body = Never
    let content: Content
    let border: Border
    let color: BorderStyle
}

extension View {
    public func border<S: Style>(_ border: Border, color: S) -> BorderView<Self, S> {
        BorderView(content: self, border: border, color: color)
    }
}

extension BorderView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .border(content, glyphs: border.glyphs, color: color.color)
    }
}
