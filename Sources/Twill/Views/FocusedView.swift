/// Associates a focus binding with a control or its focusable descendants.
public struct FocusedView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let binding: FocusBindingDescription

    init(content: Content, binding: FocusBindingDescription) {
        self.content = content
        self.binding = binding
    }
}

extension View {
    public func focused(_ binding: FocusState<Bool>.Binding) -> FocusedView<Self> {
        FocusedView(
            content: self,
            binding: FocusBindingDescription(
                isFocused: { binding.wrappedValue },
                setFocused: { if binding.wrappedValue != $0 { binding.wrappedValue = $0 } }))
    }

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
