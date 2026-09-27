/// Composes single-line content with spaces. Measurement, wrapping, and alignment are
/// not yet implemented; each child retains its own identity and scheduling state.
public struct HStack<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let separator: String

    public init(spacing: Int = 1, @ViewBuilder content: () -> Content) {
        precondition(spacing >= 0, "Stack spacing must not be negative")
        separator = String(repeating: " ", count: spacing)
        self.content = content()
    }
}

extension HStack: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], separator: separator)
    }
}
