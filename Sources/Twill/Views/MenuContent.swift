/// The sheet owns input isolation and focus restoration. Shared disabled-state
/// handling keeps unavailable menu actions out of ordinary focus traversal.
struct MenuContent: View {
    let title: String
    let items: [MenuItem]
    let isPresented: Binding<Bool>

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading) {
                ForEach(0..<items.count, id: \.self) { index in
                    let item = items[index]
                    Button(action: { activate(item) }, label: { label(for: item) })
                        .disabled(!item.isEnabled)
                }
            }
            .padding(.horizontal)
        }
        .onKeyPress { key in
            if key == .escape {
                isPresented.wrappedValue = false
                return .handled
            }
            if key != .enter, let item = items.first(where: { $0.isEnabled && $0.shortcut?.key == key }) {
                activate(item)
                return .handled
            }
            return .ignored
        }
    }

    private func label(for item: MenuItem) -> some View {
        Text(item.title + (item.shortcut.map { "  [\($0.hint)]" } ?? "") + (item.isEnabled ? "" : " (disabled)"))
    }

    private func activate(_ item: MenuItem) {
        item.action()
        isPresented.wrappedValue = false
    }
}
