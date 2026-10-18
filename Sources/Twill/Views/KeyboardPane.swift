/// Compound controls share one Tab stop while retaining their internal focus memory.
/// This scope is an implementation detail, independent of scrolling and public layout.
struct KeyboardPane<Content: View>: View {
    typealias Body = Never
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    init(content: Content) {
        self.content = content
    }
}

extension View {
    func keyboardPane() -> KeyboardPane<Self> {
        KeyboardPane(content: self)
    }
}

extension KeyboardPane: PrimitiveView {
    func makeDescription() -> ViewDescription { .pane(content) }
}
