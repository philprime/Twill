import Twill

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNoteID: Note.ID?

    private var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID } ?? notes.first
    }

    var body: some View {
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
                    return .handled
                }
            }
            if notes.isEmpty {
                Text("No matching notes")
            }
        }
    }
}
