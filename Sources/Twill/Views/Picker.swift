/// A single-choice control with typed control/option labels and externally owned values.
/// Missing values display the first option without rendering-time binding writes.
public struct Picker<SelectionValue: Hashable, Label: View, OptionLabel: View>: View {
    private let label: Label
    private let selection: Binding<SelectionValue>
    private let options: [SelectionValue]
    private let presentation: PickerPresentation
    private let optionLabel: @MainActor (SelectionValue) -> OptionLabel

    /// Creates a picker with distinct explicit values and a custom control label.
    /// Tab traverses controls in every mode. Vertical mode reserves Up/Down for selection.
    public init(
        selection: Binding<SelectionValue>, options: [SelectionValue], presentation: PickerPresentation = .inline,
        @ViewBuilder content: @escaping @MainActor (SelectionValue) -> OptionLabel, @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.selection = selection
        self.options = options
        self.presentation = presentation
        self.optionLabel = content
    }

    private var selectedIndex: Int? {
        options.firstIndex(of: selection.wrappedValue) ?? options.indices.first
    }

    private var selected: SelectionValue? { selectedIndex.map { options[$0] } }

    private var optionRows: some View {
        let selectedValue = selected
        return ForEach(options, id: \.self) { option in
            HStack {
                Text(option == selectedValue ? "[x]" : "[ ]")
                optionLabel(option)
            }.controlSelection(option == selectedValue)
        }
    }

    @ViewBuilder
    private var presentedContent: some View {
        switch presentation {
        case .inline:
            HStack {
                label
                optionRows
            }
        case .compact:
            HStack {
                label
                if let selected { optionLabel(selected).controlSelection(true) }
            }
        case .vertical:
            VStack(alignment: .leading, spacing: 0) {
                label
                optionRows
            }
        }
    }

    /// The configured layout with one control-level adjustment handler.
    public var body: some View {
        presentedContent.focusable().onKeyPress(handle).controlPresentation(.picker)
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        let backwards = key == .arrowLeft || (presentation == .vertical && key == .arrowUp)
        let forwards = key == .arrowRight || (presentation == .vertical && key == .arrowDown)
        guard backwards || forwards else { return .ignored }
        if let index = selectedIndex {
            let next = index + (forwards ? 1 : -1)
            if options.indices.contains(next) { selection.wrappedValue = options[next] }
        }
        return .handled
    }
}
