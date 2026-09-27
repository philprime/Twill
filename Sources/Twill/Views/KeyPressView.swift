/// Handles keys delivered to this view or bubbling from its focused descendants.
public struct KeyPressView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let action: @MainActor (KeyEvent) -> KeyPressResult

    init(content: Content, action: @escaping @MainActor (KeyEvent) -> KeyPressResult) {
        self.content = content
        self.action = action
    }
}

extension View {
    public func onKeyPress(_ action: @escaping @MainActor (KeyEvent) -> KeyPressResult) -> KeyPressView<Self> {
        KeyPressView(content: self, action: action)
    }
}

extension KeyPressView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyPress(content, action)
    }
}
