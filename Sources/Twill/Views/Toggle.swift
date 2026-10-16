/// A labeled checkbox backed by a Boolean binding. Space changes its value;
/// focus highlighting is independent of the checkmark.
public struct Toggle<Label: View>: View {
    private let isOn: Binding<Bool>
    private let label: Label

    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: 1) {
            Text(isOn.wrappedValue ? "[x]" : "[ ]")
            label
        }
        .focusable()
        .onKeyPress { key in
            guard key == .space else { return .ignored }
            isOn.wrappedValue.toggle()
            return .handled
        }
    }
}

extension Toggle where Label == Text {
    public init(_ title: String, isOn: Binding<Bool>) {
        self.isOn = isOn
        self.label = Text(title)
    }
}
