/// A labeled control opening builder-based actions in a separate keyboard scope.
public struct Menu<Label: View, Content: View>: View {
    @State private var isPresented = false
    private let title: String?
    private let label: Label
    private let content: Content

    /// Creates a menu from ordinary buttons, conditional content, and keyed collections.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.title = nil
        self.label = label()
        self.content = content()
    }

    /// The opener and its modal action content.
    public var body: some View {
        Button(action: { isPresented = true }, label: { label })
            .sheet(isPresented: $isPresented) {
                MenuContent(title: title, content: content, isPresented: $isPresented)
            }
    }
}

extension Menu where Label == Text {
    /// Creates a text-labeled menu using ordinary button content.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.label = Text(title)
        self.content = content()
    }
}
