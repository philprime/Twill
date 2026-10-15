/// Encloses content in a border with a title inset into its top edge.
/// Add padding to the content when space between it and the border is desired.
public struct GroupBox<Content: View>: View {
    public typealias Body = Never
    private let title: String
    private let border: Border
    private let content: Content

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
