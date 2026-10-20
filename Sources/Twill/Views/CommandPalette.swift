/// Searches available command snapshots without registering their advertised shortcuts.
/// Search focus and effective command selection remain independent.
public struct CommandPalette<ID: Hashable>: View {
    @State private var query = ""
    @State private var selectedID: ID?
    private let title: String
    private let commands: [Command<ID>]
    private let maximumVisibleCommands: Int
    private let dismiss: @MainActor () -> Void

    /// Creates a palette with a positive visible-row limit and an explicit dismiss request.
    /// Unavailable commands are omitted; matches retain caller order.
    public init(
        _ title: String = "Commands", commands: [Command<ID>], maximumVisibleCommands: Int = 8,
        dismiss: @escaping @MainActor () -> Void
    ) {
        precondition(maximumVisibleCommands > 0, "A command palette must offer at least one row")
        self.title = title
        self.commands = commands
        self.maximumVisibleCommands = maximumVisibleCommands
        self.dismiss = dismiss
    }

    private var matches: [Command<ID>] {
        let search = query.lowercased()
        return commands.filter { $0.isEnabled && (search.isEmpty || $0.title.lowercased().contains(search)) }
    }

    /// Search, bounded selectable results, and status content use ordinary mounted controls.
    public var body: some View {
        let visible = matches
        return GroupBox(title) {
            VStack(alignment: .leading, spacing: 1) {
                TextField("Search commands", text: $query, onVerticalMove: { _ = handle($0) })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit(activateSelection)
                if visible.isEmpty {
                    ContentUnavailableView("No matching commands")
                        .frame(height: 3, maxWidth: .infinity)
                } else {
                    List(visible, selection: $selectedID) { command in
                        HStack {
                            Text(command.title)
                            Spacer()
                            Text(command.shortcuts.map(\.hint).joined(separator: "/"))
                                .foregroundStyle(.muted)
                        }
                    }
                    .onActivate(activate)
                    .frame(height: min(maximumVisibleCommands, visible.count), maxWidth: .infinity)
                }
                StatusBar { Text("↑/↓ choose  Enter run  Escape cancel") }
                    .foregroundStyle(.muted)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onKeyPress(handle)
    }

    private func activateSelection() {
        if let command = SelectionPolicy.firstVisible.resolve(in: matches, selection: selectedID) { activate(command) }
    }

    private func activate(_ command: Command<ID>) {
        command.perform()
        dismiss()
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        if key == .escape {
            dismiss()
            return .handled
        }
        guard key == .arrowDown || key == .arrowUp else { return .ignored }
        let visible = matches
        let index = SelectionPolicy.firstVisible.navigationIndex(
            for: key, in: visible, selection: selectedID, id: { $0.id })
        if let index {
            let next = visible[index].id
            if selectedID != next { selectedID = next }
        }
        return .handled
    }
}

extension View {
    /// Opens a command palette in an ordinary sheet with lifetime-scoped dismissal.
    public func commandPalette<ID: Hashable>(
        _ title: String = "Commands", isPresented: Binding<Bool>, commands: [Command<ID>]
    ) -> some View {
        sheet(isPresented: isPresented) { dismiss in
            CommandPalette(title, commands: commands, dismiss: dismiss.callAsFunction)
        }
    }
}
