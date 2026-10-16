/// A labeled control that opens a keyboard-scoped list of contextual actions.
public struct Menu: View {
    @State private var isPresented = false
    private let title: String
    private let items: [MenuItem]

    /// Creates a menu button with the given title and ordered action items.
    public init(_ title: String, items: [MenuItem]) {
        self.title = title
        self.items = items
    }

    /// The button and the modal action list it opens.
    public var body: some View {
        Button(title) { isPresented = true }
            .sheet(isPresented: $isPresented) {
                MenuContent(title: title, items: items, isPresented: $isPresented)
            }
    }
}
