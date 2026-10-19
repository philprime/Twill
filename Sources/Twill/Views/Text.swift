/// Text measured and drawn in terminal cells, preserving line breaks and wrapping
/// at spaces within a finite proposed width. Other control characters are replaced with spaces.
public struct Text: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: String

    /// Creates terminal text from the supplied string.
    public init(_ content: String) {
        self.content = content
    }
}

extension Text: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .text(MultilineTextDrawing(content))
    }
}
