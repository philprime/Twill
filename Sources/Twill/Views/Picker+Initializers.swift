extension Picker where Label == Text {
    /// Creates a titled picker, preserving inline presentation by default.
    /// The title includes a colon; custom labels own their own punctuation.
    public init(
        _ title: String, selection: Binding<SelectionValue>, options: [SelectionValue],
        presentation: PickerPresentation = .inline,
        @ViewBuilder content: @escaping @MainActor (SelectionValue) -> OptionLabel
    ) {
        self.init(
            selection: selection, options: options, presentation: presentation,
            content: content, label: { return Text("\(title):") })
    }
}

extension Picker where SelectionValue == String, Label == Text, OptionLabel == Text {
    /// Creates a titled picker displaying each explicit string value directly.
    public init(
        _ title: String, selection: Binding<String>, options: [String], presentation: PickerPresentation = .inline
    ) {
        self.init(
            title, selection: selection, options: options, presentation: presentation, content: { return Text($0) })
    }
}

extension Picker where SelectionValue == String, OptionLabel == Text {
    /// Creates a string-option picker with a custom typed control label.
    public init(
        selection: Binding<String>, options: [String], presentation: PickerPresentation = .inline,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            selection: selection, options: options, presentation: presentation,
            content: { return Text($0) }, label: label)
    }
}
