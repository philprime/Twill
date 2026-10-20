import Twill

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNoteID: Note.ID?
    let onDelete: @MainActor (Note.ID) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            List(notes, selection: $selectedNoteID, selectionPolicy: .firstVisible) { note in
                VStack(alignment: .leading) {
                    Text(note.title)
                        .foregroundStyle(.foreground)
                    Text(note.summary)
                        .frame(width: 22, alignment: .leading)
                        .foregroundStyle(.muted)
                }
            }
            .onKeyPress { key in
                guard key == .d,
                    let note = SelectionPolicy.firstVisible.resolve(in: notes, selection: selectedNoteID)
                else { return .ignored }
                onDelete(note.id)
                return .handled
            }
            if notes.isEmpty {
                ContentUnavailableView("No matching notes", description: "Try another search.")
                    .foregroundStyle(.muted)
            }
        }
    }
}
