/// Single-line text measured and drawn in terminal cells. Control characters are replaced with spaces.
public struct Text: View {
    public typealias Body = Never
    private let content: String

    public init(_ content: String) {
        self.content = content
    }
}

extension Text: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .drawing(TextDrawing(content))
    }
}
