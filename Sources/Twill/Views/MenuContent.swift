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
                    Button(role: item.role, action: { activate(item) }, label: { label(for: item) })
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
            guard key != .enter else { return .ignored }
            let item = items.first { $0.isEnabled && $0.shortcuts.contains(where: { $0.key == key }) }
            guard let item else { return .ignored }
            activate(item)
            return .handled
        }
    }

    private func label(for item: MenuItem) -> some View {
        let hints = item.shortcuts.map(\.hint).joined(separator: "/")
        return Text(item.title + (hints.isEmpty ? "" : "  [\(hints)]") + (item.isEnabled ? "" : " (disabled)"))
    }

    private func activate(_ item: MenuItem) {
        item.action()
        isPresented.wrappedValue = false
    }
}
