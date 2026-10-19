/// Supplies inherited indicator visibility to scroll viewports in its content.
public struct ScrollIndicatorView<Content: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let content: Content
    private let visibility: ScrollIndicatorVisibility

    init(content: Content, visibility: ScrollIndicatorVisibility) {
        self.content = content
        self.visibility = visibility
    }
}

extension View {
    /// Sets vertical indicator visibility. The nearest setting wins; the default is hidden.
    /// Visible viewports reserve a column even when content fits, keeping reflow deterministic.
    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility) -> ScrollIndicatorView<Self> {
        ScrollIndicatorView(content: self, visibility: visibility)
    }
}

extension ScrollIndicatorView: PrimitiveView {
    func makeDescription() -> ViewDescription { .scrollIndicators(content, visibility) }
}
