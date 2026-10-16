/// A bound text input that masks its value with one bullet per character.
/// The binding and submit actions retain the original value. Masking protects
/// terminal presentation, not the value's storage in application memory.
public struct SecureField: View {
    private let prompt: String
    private let text: Binding<String>

    /// Creates a bound text field that displays mask characters instead of the entered value.
    public init(_ prompt: String, text: Binding<String>) {
        self.prompt = prompt
        self.text = text
    }

    /// The secure text field sharing the caller's text binding.
    public var body: some View {
        TextField(prompt, text: text, isSecure: true)
    }
}
