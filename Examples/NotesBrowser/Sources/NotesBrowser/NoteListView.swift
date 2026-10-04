import Twill

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNoteID: Note.ID?
    let onDelete: @MainActor (Note.ID) -> Void

    private var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID } ?? notes.first
    }

    var body: some View {
        VStack {
            ForEach(notes) { note in
                VStack(alignment: .leading) {
                    HStack {
                        Text(note.id == selectedNote?.id ? "▸" : "•")
                            .focusable()
                            .onKeyPress { key in
                                if key == .enter {
                                    selectedNoteID = note.id
                                    return .handled
                                }
                                if key == .d {
                                    onDelete(note.id)
                                    return .handled
                                }
                                guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return .ignored }
                                switch key {
                                case .arrowDown, .arrowRight:
                                    if notes.indices.contains(index + 1) { selectedNoteID = notes[index + 1].id }
                                case .arrowUp, .arrowLeft:
                                    if notes.indices.contains(index - 1) { selectedNoteID = notes[index - 1].id }
                                default: break
                                }
                                // Selection follows list focus, while the runtime still owns focus traversal.
                                return .ignored
                            }
                        Text(note.title)
                            .foregroundStyle(
                                note.id == selectedNote?.id ? NotesPalette.accent : NotesPalette.foreground)
                    }
                    Text(note.summary)
                        .frame(width: 22, alignment: .leading)
                        .foregroundStyle(NotesPalette.muted)
                }
            }
            if notes.isEmpty {
                Text("No matching notes")
                    .foregroundStyle(NotesPalette.muted)
            }
        }
    }
}
