/// Sheet lifetime owns key isolation and focus restoration; the menu marker scopes
/// action dismissal without replacing ordinary button eligibility or shortcuts.
struct MenuContent<Content: View>: View, PrimitiveView {
    let title: String?
    let content: Content
    let isPresented: Binding<Bool>

    var body: some View {
        GroupBox(title ?? "") {
            VStack(alignment: .leading) { content }.padding(.horizontal)
        }.onKeyPress { key in
            guard key == .escape else { return .ignored }
            isPresented.wrappedValue = false
            return .handled
        }
    }

    func makeDescription() -> ViewDescription { .menu(body, isPresented) }
}
