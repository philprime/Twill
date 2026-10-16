/// Associates a focus binding with a control or its focusable descendants.
public struct FocusedView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let binding: FocusBindingDescription

    init(content: Content, binding: FocusBindingDescription) {
        self.content = content
        self.binding = binding
    }
}

extension View {
    /// Synchronizes focus for this content with a Boolean focus binding.
    public func focused(_ binding: FocusState<Bool>.Binding) -> FocusedView<Self> {
        FocusedView(
            content: self,
            binding: FocusBindingDescription(
                isFocused: { binding.wrappedValue },
                setFocused: { if binding.wrappedValue != $0 { binding.wrappedValue = $0 } }))
    }

    /// Associates this content with a focus value. Gaining focus writes that value; losing it clears a matching value.
    public func focused<Value: Hashable>(
        _ binding: FocusState<Value?>.Binding, equals value: Value
    ) -> FocusedView<Self> {
        FocusedView(
            content: self,
            binding: FocusBindingDescription(
                isFocused: { binding.wrappedValue == value },
                setFocused: { focused in
                    if focused, binding.wrappedValue != value { binding.wrappedValue = value }
                    if !focused, binding.wrappedValue == value { binding.wrappedValue = nil }
                }))
    }
}

struct FocusBindingDescription {
    let isFocused: @MainActor () -> Bool
    let setFocused: @MainActor (Bool) -> Void
}

extension FocusedView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .focusBinding(content, binding)
    }
}
