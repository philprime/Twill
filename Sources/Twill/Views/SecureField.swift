/// A bound text input that masks its value with one bullet per character.
/// The binding and submit actions retain the original value. Masking protects
/// terminal presentation, not the value's storage in application memory.
public struct SecureField: View {
    private let prompt: String
    private let text: Binding<String>
    private let editingMode: TextEditingMode

    /// Creates a bound field that masks its value in either editing mode.
    /// Read-only mode retains navigation and submit routing without user edits.
    public init(_ prompt: String, text: Binding<String>, editingMode: TextEditingMode = .editable) {
        self.prompt = prompt
        self.text = text
        self.editingMode = editingMode
    }

    /// The secure text field sharing the caller's text binding.
    public var body: some View {
        TextField(prompt, text: text, isSecure: true, editingMode: editingMode)
    }
}
