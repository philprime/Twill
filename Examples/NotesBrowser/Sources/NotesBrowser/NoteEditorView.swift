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
            ScrollView {
                TextField("Title", text: $title)
            }
            .frame(height: 1)
            .border(.single, color: NotesPalette.border)
            Text("Body")
            TextEditor(text: $noteText)
                .frame(height: 6)
                .border(.single, color: NotesPalette.border)
            ScrollView {
                VStack(alignment: .leading) {
                    Button(saveLabel, action: onSave)
                        .foregroundStyle(NotesPalette.accent)
                    Button("Cancel", action: onCancel)
                }
            }
            .frame(height: 2)
            Text("Tab: pane  •  Enter: newline/choose  •  Esc: cancel")
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
