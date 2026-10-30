import Twill

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.title).bold()
                .foregroundStyle(.tint)
            if note.body.allSatisfy(\.isWhitespace) {
                Text("No body yet")
                    .foregroundStyle(.secondary)
            } else {
                Text(note.body)
                    .foregroundStyle(NotesPalette.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
