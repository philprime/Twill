/// A labeled checkbox backed by a Boolean binding. Space changes its value;
/// focus highlighting is independent of the checkmark.
public struct Toggle<Label: View>: View {
    private let isOn: Binding<Bool>
    private let label: Label

    /// Creates a Space-activated checkbox with a custom label and externally owned Boolean value.
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    /// The checkmark and label with focus and Space-key handling.
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
    /// Creates a text-labeled checkbox backed by the supplied Boolean binding.
    public init(_ title: String, isOn: Binding<Bool>) {
        self.isOn = isOn
        self.label = Text(title)
    }
}
