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
                    Text(note.id == selectedNote?.id ? "▸" : "•")
                        .foregroundStyle(NotesPalette.marker)
                    if note.id == selectedNote?.id {
                        Text(note.title)
                            .foregroundStyle(NotesPalette.background)
                            .backgroundStyle(NotesPalette.accent)
                    } else {
                        Text(note.title)
                            .foregroundStyle(NotesPalette.foreground)
                    }
                }
                .focusable()
                .onKeyPress { key in
                    if key == .enter {
                        selectedNoteID = note.id
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
            }
            if notes.isEmpty {
                Text("No matching notes")
                    .foregroundStyle(NotesPalette.muted)
            }
        }
    }
}
