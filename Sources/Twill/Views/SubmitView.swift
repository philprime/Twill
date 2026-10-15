/// Handles submission from a focused text field within this view.
public struct SubmitView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let action: @MainActor () -> Void

    init(content: Content, action: @escaping @MainActor () -> Void) {
        self.content = content
        self.action = action
    }
}

extension View {
    public func onSubmit(_ action: @escaping @MainActor () -> Void) -> SubmitView<Self> {
        SubmitView(content: self, action: action)
    }
}

extension SubmitView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .submit(content, action)
    }
}
