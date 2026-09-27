import Twill

struct NotesBrowserView: View {
    private enum Screen {
        case list
        case detail(Note)
    }

    private let notes = [
        Note(id: "groceries", title: "Groceries", summary: "Bread and coffee"),
        Note(id: "weekend", title: "Weekend", summary: "Visit the coast"),
    ]

    // Selection outlives the list view. The list resolves missing IDs to its first note.
    @State private var selectedNoteID: Note.ID?
    @State private var query = ""
    @State private var screen: Screen = .list
    @State private var isHelpPresented = false

    private var matchingNotes: [Note] {
        notes.filter { query.isEmpty || $0.title.lowercased().contains(query.lowercased()) }
    }

    var body: some View {
        Group {
            if case .detail(let note) = screen {
                NoteDetailView(
                    note: note,
                    onBack: { screen = .list },
                    onShowHelp: { isHelpPresented = true }
                )
            } else {
                NoteListView(
                    notes: matchingNotes,
                    selectedNoteID: $selectedNoteID,
                    query: $query,
                    onOpenNote: { screen = .detail($0) },
                    onShowHelp: { isHelpPresented = true }
                )
            }
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView(onDismiss: { isHelpPresented = false })
        }
    }
}
