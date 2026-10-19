/// A labeled section whose bound expansion state is toggled with Enter or Space.
/// Collapsing returns focus from a hidden child to the header. Focus outside the section is unchanged.
/// Collapsed content is unmounted. Keep values that must survive collapse in an
/// ancestor and pass them into the content through bindings.
public struct DisclosureGroup<Label: View, Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let isExpanded: Binding<Bool>
    private let content: @MainActor () -> Content
    private let label: Label

    /// Creates a disclosure control with a custom label and externally owned expansion state.
    /// The content closure supplies children while expanded.
    public init(
        isExpanded: Binding<Bool>, @ViewBuilder content: @escaping @MainActor () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.isExpanded = isExpanded
        self.content = content
        self.label = label()
    }

    private var header: some View {
        HStack(spacing: 1) {
            Text(isExpanded.wrappedValue ? "▾" : "▸")
            label
        }
        .focusable()
        .onKeyPress { key in
            guard key == .enter || key == .space else { return .ignored }
            isExpanded.wrappedValue.toggle()
            return .handled
        }
        .controlPresentation(.disclosure, selected: isExpanded.wrappedValue)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.leading, 2)
    }
}

extension DisclosureGroup where Label == Text {
    /// Creates a text-labeled disclosure control using the supplied expansion binding.
    public init(
        _ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.init(isExpanded: isExpanded, content: content, label: { return Text(title) })
    }
}

extension DisclosureGroup: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .disclosure(header: header, content: isExpanded.wrappedValue ? expandedContent : nil)
    }
}
