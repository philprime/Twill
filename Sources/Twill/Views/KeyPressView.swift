/// Handles keys delivered to this view or bubbling from its focused descendants.
public struct KeyPressView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let action: @MainActor (KeyEvent) -> KeyPressResult

    init(content: Content, action: @escaping @MainActor (KeyEvent) -> KeyPressResult) {
        self.content = content
        self.action = action
    }
}

extension View {
    /// Handles keys routed through this content. Return `.ignored` to let a key bubble to an enclosing handler.
    public func onKeyPress(_ action: @escaping @MainActor (KeyEvent) -> KeyPressResult) -> KeyPressView<Self> {
        KeyPressView(content: self, action: action)
    }
}

extension KeyPressView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyPress(content, action)
    }
}
