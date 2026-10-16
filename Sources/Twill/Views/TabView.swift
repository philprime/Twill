/// Switches between mounted destinations while retaining their state.
/// Left/Right selects tabs when the bar is focused. Control-PageUp and
/// Control-PageDown switch from within content without wrapping.
/// Tab or Down enters content. Shift-Tab returns to the bar from the first pane
/// or from content without panes, preserving the destination's remembered focus.
/// An absent selection displays the first tab without changing the binding.
/// Inactive contents retain their tasks and timeline schedules.
public struct TabView<SelectionValue: Hashable, Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let selection: Binding<SelectionValue>
    private let content: Content

    /// Creates a tab container whose active tab is controlled by the supplied selection binding.
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.content = content()
    }
}

extension TabView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .tabs(
            content,
            selection: Binding(
                get: { AnyHashable(selection.wrappedValue) },
                set: { value in
                    guard let value = value.base as? SelectionValue else {
                        preconditionFailure("Tab values must match the selection binding's type")
                    }
                    selection.wrappedValue = value
                }))
    }
}
