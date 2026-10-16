/// A labeled destination in a tab view. Values must be unique within the
/// enclosing tab view and match its selection binding's type.
public struct Tab<SelectionValue: Hashable, Content: View>: View {
    public typealias Body = Never
    private let title: String
    private let value: SelectionValue
    private let content: Content

    public init(_ title: String, value: SelectionValue, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }
}

extension Tab: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .tab(content, title: title, value: AnyHashable(value))
    }
}
