/// Keeps content visible while controlling whether it can receive user input.
public struct DisabledView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let isDisabled: Bool

    init(content: Content, isDisabled: Bool) {
        self.content = content
        self.isDisabled = isDisabled
    }
}

extension View {
    /// Disables interaction and focus for this content and its descendants.
    /// A disabled ancestor cannot be re-enabled by a descendant. Content stays
    /// mounted and visible, retaining its state, selection, and schedules.
    public func disabled(_ isDisabled: Bool) -> DisabledView<Self> {
        DisabledView(content: self, isDisabled: isDisabled)
    }
}

extension DisabledView: PrimitiveView {
    func makeDescription() -> ViewDescription { .disabled(content, isDisabled) }
}
