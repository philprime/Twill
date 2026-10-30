import Twill

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.title)
                .foregroundStyle(NotesPalette.accent)
            if note.body.allSatisfy(\.isWhitespace) {
                Text("No body yet")
                    .foregroundStyle(NotesPalette.muted)
            } else {
                Text(note.body)
                    .foregroundStyle(NotesPalette.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
