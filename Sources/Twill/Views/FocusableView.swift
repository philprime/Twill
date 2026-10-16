/// A single keyboard focus target, distinct from any focusable descendants.
public struct FocusableView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content

    init(content: Content) {
        self.content = content
    }
}

extension View {
    /// Makes the content a keyboard focus target, distinct from any focusable descendants.
    public func focusable() -> FocusableView<Self> {
        FocusableView(content: self)
    }
}

extension FocusableView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .focusable(content)
    }
}
