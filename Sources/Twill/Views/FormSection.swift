/// Groups form entries under a noninteractive heading.
public struct FormSection<Content: View>: View {
    private let title: String
    private let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            VStack(alignment: .leading, spacing: 1) { content }
        }
    }
}
