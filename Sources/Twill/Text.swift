/// Plain text. The initial presenter supports a single line, not terminal-cell layout.
public struct Text: View {
    public typealias Body = Never
    private let content: String

    public init(_ content: String) {
        self.content = content
    }
}

extension Text: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .text(content)
    }
}
