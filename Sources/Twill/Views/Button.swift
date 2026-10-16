/// A focusable action control that consumes Enter and lets other keys bubble.
public struct Button<Label: View>: View {
    private let action: @MainActor () -> Void
    private let label: Label
    private let role: ButtonRole?

    /// Creates an Enter-activated button with a custom label and an optional dialog role.
    public init(role: ButtonRole? = nil, action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
        self.role = role
    }

    /// The focusable label and its Enter-key action handler.
    public var body: some View {
        label
            .focusable()
            .onKeyPress { key in
                guard key == .enter else { return .ignored }
                action()
                return .handled
            }
    }
}

extension Button: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .button(body, role: role, action: action)
    }
}

extension Button where Label == Text {
    /// Creates an Enter-activated button with a text label and an optional dialog role.
    public init(_ title: String, role: ButtonRole? = nil, action: @escaping @MainActor () -> Void) {
        self.action = action
        self.label = Text(title)
        self.role = role
    }
}
