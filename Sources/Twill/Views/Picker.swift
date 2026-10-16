/// A single-choice control with a bound value and a label for each option.
/// Left and Right select options without wrapping. Up and Down remain available
/// for focus traversal, and selection stays marked when focus moves away.
public struct Picker<SelectionValue: Hashable, OptionLabel: View>: View {
    private let title: String
    private let selection: Binding<SelectionValue>
    private let options: [SelectionValue]
    private let optionLabel: @MainActor (SelectionValue) -> OptionLabel

    /// Supply distinct option values. An absent selection displays the first
    /// option without changing the binding until the user chooses another value.
    public init(
        _ title: String, selection: Binding<SelectionValue>, options: [SelectionValue],
        @ViewBuilder content: @escaping @MainActor (SelectionValue) -> OptionLabel
    ) {
        self.title = title
        self.selection = selection
        self.options = options
        self.optionLabel = content
    }

    private var selectedIndex: Int? {
        options.firstIndex(of: selection.wrappedValue) ?? options.indices.first
    }

    public var body: some View {
        let selected = selectedIndex.map { options[$0] }
        return HStack {
            Text("\(title):")
            ForEach(options, id: \.self) { option in
                HStack {
                    Text(option == selected ? "[x]" : "[ ]")
                    optionLabel(option)
                }
            }
        }
        .focusable()
        .onKeyPress { key in
            guard key == .arrowLeft || key == .arrowRight else { return .ignored }
            if let index = selectedIndex {
                let next = index + (key == .arrowRight ? 1 : -1)
                if options.indices.contains(next) {
                    selection.wrappedValue = options[next]
                }
            }
            return .handled
        }
    }
}
