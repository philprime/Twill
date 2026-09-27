import Twill

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNoteID: Note.ID?
    @Binding var query: String
    let onOpenNote: @MainActor (Note) -> Void
    let onShowHelp: @MainActor () -> Void

    private var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID } ?? notes.first
    }

    var body: some View {
        VStack {
            Text("Notes")
            VStack {
                ForEach(notes) { note in
                    HStack {
                        Text(note.id == selectedNote?.id ? ">" : " ")
                        Text(note.title)
                    }
                    .focusable()
                    .onKeyPress { key in
                        guard key == .enter else { return .ignored }
                        selectedNoteID = note.id
                        onOpenNote(note)
                        return .handled
                    }
                }
                if notes.isEmpty {
                    Text("No matching notes")
                }
            }
            TextField("Search notes", text: $query)
            Text("[Arrows: focus | Enter: open/edit | Esc: stop editing | ?: help]")
        }
        .onKeyPress { key in
            // Editing consumes text input instead of invoking screen shortcuts.
            guard key == .character("?") else { return .ignored }
            onShowHelp()
            return .handled
        }
    }
}
