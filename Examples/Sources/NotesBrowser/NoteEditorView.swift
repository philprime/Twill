import Foundation
import Twill

struct NoteEditorView: View {
    @Binding var title: String
    @Binding var noteText: String
    let heading: String
    let saveLabel: String
    let onSave: @MainActor () -> Void
    let onCancel: @MainActor () -> Void

    var body: some View {
        Form {
            FormSection(heading) {
                FormField(
                    "Title", help: "A title is required to save.",
                    validationMessage: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Enter a title." : nil
                ) {
                    ScrollView {
                        TextField("Title", text: $title)
                    }
                    .frame(height: 1)
                    .border(.single, color: NotesPalette.border)
                }
                FormField("Body") {
                    TextEditor(text: $noteText)
                        .frame(height: 6)
                        .border(.single, color: NotesPalette.border)
                }
            }
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
