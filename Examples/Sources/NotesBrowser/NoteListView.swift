import Twill

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNoteID: Note.ID?
    let onDelete: @MainActor (Note.ID) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            List(notes, selection: $selectedNoteID) { note in
                VStack(alignment: .leading) {
                    Text(note.title)
                        .foregroundStyle(NotesPalette.foreground)
                    Text(note.summary)
                        .frame(width: 22, alignment: .leading)
                        .foregroundStyle(.secondary)
                }
            }
            .onKeyPress { key in
                guard key == .d,
                    let note = notes.first(where: { $0.id == selectedNoteID }) ?? notes.first
                else { return .ignored }
                onDelete(note.id)
                return .handled
            }
            if notes.isEmpty {
                Text("No matching notes")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
