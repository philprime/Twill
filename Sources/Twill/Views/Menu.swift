/// A labeled control that opens a keyboard-scoped list of contextual actions.
public struct Menu: View {
    @State private var isPresented = false
    private let title: String
    private let items: [MenuItem]

    public init(_ title: String, items: [MenuItem]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        Button(title) { isPresented = true }
            .sheet(isPresented: $isPresented) {
                MenuContent(title: title, items: items, isPresented: $isPresented)
            }
    }
}
