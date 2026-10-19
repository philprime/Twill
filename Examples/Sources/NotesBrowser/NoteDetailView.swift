import Twill

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.title).bold()
                .foregroundStyle(.accent)
            if note.body.allSatisfy(\.isWhitespace) {
                Text("No body yet")
                    .foregroundStyle(.muted)
            } else {
                Text(note.body)
                    .foregroundStyle(.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
