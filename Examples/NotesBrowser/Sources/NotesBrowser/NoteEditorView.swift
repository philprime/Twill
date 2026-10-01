import Twill

struct NoteEditorView: View {
    @Binding var title: String
    @Binding var noteText: String
    let heading: String
    let saveLabel: String
    let onSave: @MainActor () -> Void
    let onCancel: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(heading)
                .foregroundStyle(NotesPalette.accent)
            Text("Title (required)")
            TextField("Title", text: $title)
                .border(.single, color: NotesPalette.border)
            Text("Body")
            TextField("Body", text: $noteText)
                .border(.single, color: NotesPalette.border)
            Text(saveLabel)
                .focusable()
                .onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    onSave()
                    return .handled
                }
                .foregroundStyle(NotesPalette.accent)
            Text("Cancel")
                .focusable()
                .onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    onCancel()
                    return .handled
                }
            Text("Enter: edit/choose  •  Esc: cancel")
                .foregroundStyle(NotesPalette.muted)
        }
        .foregroundStyle(NotesPalette.foreground)
        .frame(width: 58, alignment: .topLeading)
        .border(.single, color: NotesPalette.border)
        .onKeyPress { key in
            guard key == .escape else { return .ignored }
            onCancel()
            return .handled
        }
    }
}
