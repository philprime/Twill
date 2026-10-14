/// A focusable action control that consumes Enter and lets other keys bubble.
public struct Button<Label: View>: View {
    private let action: @MainActor () -> Void
    private let label: Label

    public init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

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

extension Button where Label == Text {
    public init(_ title: String, action: @escaping @MainActor () -> Void) {
        self.action = action
        self.label = Text(title)
    }
}
