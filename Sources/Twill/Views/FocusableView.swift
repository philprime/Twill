/// A single keyboard focus target, distinct from any focusable descendants.
public struct FocusableView<Content: View>: View {
    public typealias Body = Never
    private let content: Content

    init(content: Content) {
        self.content = content
    }
}

extension View {
    public func focusable() -> FocusableView<Self> {
        FocusableView(content: self)
    }
}

extension FocusableView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .focusable(content)
    }
}
