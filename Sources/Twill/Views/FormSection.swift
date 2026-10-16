/// Groups form entries under a noninteractive heading.
public struct FormSection<Content: View>: View {
    private let title: String
    private let content: Content

    /// Creates a form section with a noninteractive title and spaced entries.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    /// The heading followed by leading-aligned entries separated by one row.
    public var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            VStack(alignment: .leading, spacing: 1) { content }
        }
    }
}
