import Twill

struct NotesBrowserView: View {
    private let notes = [
        Note(id: "groceries", title: "Groceries", summary: "Bread and coffee"),
        Note(id: "weekend", title: "Weekend", summary: "Visit the coast"),
    ]

    // Selection outlives the list view. The list resolves missing IDs to its first note.
    @State private var selectedNoteID: Note.ID?
    @State private var query = ""
    @State private var isHelpPresented = false

    private var matchingNotes: [Note] {
        notes.filter { query.isEmpty || $0.title.lowercased().contains(query.lowercased()) }
    }

    private var selectedNote: Note? {
        matchingNotes.first { $0.id == selectedNoteID } ?? matchingNotes.first
    }

    var body: some View {
        VStack(spacing: 1) {
            Text("Notes")
            TextField("Search notes", text: $query)
            HStack(spacing: 2) {
                NoteListView(
                    notes: matchingNotes,
                    selectedNoteID: $selectedNoteID
                )
                .frame(maxWidth: 24)
                if let selectedNote {
                    NoteDetailView(note: selectedNote, onShowHelp: { isHelpPresented = true })
                }
            }
        }
        .onKeyPress { key in
            // Editing consumes text input instead of invoking screen shortcuts.
            guard key == .character("?") else { return .ignored }
            isHelpPresented = true
            return .handled
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView(onDismiss: { isHelpPresented = false })
        }
    }
}
