/// Encloses content in a border with a title inset into its top edge.
/// Add padding to the content when space between it and the border is desired.
public struct GroupBox<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let title: String
    private let border: Border
    private let content: Content

    /// Creates a titled group with the supplied one-cell border and built content.
    public init(
        _ title: String, border: Border = .rounded,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.border = border
        self.content = content()
    }
}

extension GroupBox: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .border(
            content, glyphs: border.glyphs, color: nil,
            title: title.isEmpty ? nil : TextDrawing(" " + title + " "))
    }
}
