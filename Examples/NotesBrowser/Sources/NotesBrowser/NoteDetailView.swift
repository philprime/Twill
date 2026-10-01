import Twill

struct NoteDetailView: View {
    let note: Note

    private var lines: [String] {
        var result: [String] = []
        var line = ""
        for word in note.body.split(separator: " ") {
            if !line.isEmpty && line.count + word.count + 1 > 52 {
                result.append(line)
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        if !line.isEmpty { result.append(line) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.title)
                .foregroundStyle(NotesPalette.accent)
            if lines.isEmpty {
                Text("No body yet")
                    .foregroundStyle(NotesPalette.muted)
            }
            ForEach(0..<lines.count, id: \.self) { index in
                Text(lines[index])
                    .foregroundStyle(NotesPalette.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
