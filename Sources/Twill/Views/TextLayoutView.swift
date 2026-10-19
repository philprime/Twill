/// Supplies inherited layout policy to static Text descendants.
public struct TextLayoutView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let change: TextLayoutChange

    init(content: Content, change: TextLayoutChange) {
        self.content = content
        self.change = change
    }
}

extension View {
    /// Chooses word wrapping, grapheme wrapping, or clipping for Text descendants.
    public func lineBreakMode(_ mode: Text.LineBreakMode) -> TextLayoutView<Self> {
        TextLayoutView(content: self, change: .lineBreakMode(mode))
    }

    /// Limits visible Text lines. Nil removes the inherited limit. Like SwiftUI,
    /// values below one use one line. Omitted content defaults to tail truncation.
    public func lineLimit(_ limit: Int?) -> TextLayoutView<Self> {
        TextLayoutView(content: self, change: .lineLimit(limit.map { max(1, $0) }))
    }

    /// Selects the ellipsis position when constrained Text omits content.
    public func truncationMode(_ mode: Text.TruncationMode) -> TextLayoutView<Self> {
        TextLayoutView(content: self, change: .truncationMode(mode))
    }
}

extension TextLayoutView: PrimitiveView {
    func makeDescription() -> ViewDescription { .textLayout(content, change) }
}
