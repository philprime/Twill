/// Stacks a label, control content, optional help, and a red validation message.
/// Validation belongs to the caller. A message does not disable editing or submission.
public struct FormField<Content: View>: View {
    private let title: String
    private let help: String?
    private let validationMessage: String?
    private let content: Content

    public init(
        _ title: String, help: String? = nil, validationMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.help = help
        self.validationMessage = validationMessage
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            content
            if let help { Text(help) }
            if let validationMessage {
                Text(validationMessage).foregroundStyle(Color.red)
            }
        }
    }
}
