import Foundation
import Twill

struct NoteEditorView: View {
    @Binding var title: String
    @Binding var noteText: String
    let heading: String
    let saveLabel: String
    let onSave: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
    private let saveShortcut = KeyboardShortcut(.controlS)
    private let superSaveShortcut = KeyboardShortcut(.superS)

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            FormSection(heading) {
                FormField(
                    "Title", help: "A title is required to save.",
                    validationMessage: isTitleEmpty ? "Enter a title." : nil
                ) {
                    TextField("Title", text: $title)
                        .border(.single, color: NotesPalette.border)
                }
                FormField("Body") {
                    TextEditor(text: $noteText)
                        .frame(height: 6)
                        .border(.single, color: NotesPalette.border)
                }
            }
            VStack(alignment: .leading) {
                Button(saveLabel, action: onSave)
                    .foregroundStyle(NotesPalette.accent)
                    .disabled(isTitleEmpty)
                    .keyboardShortcut([saveShortcut, superSaveShortcut])
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
            }
            Text("\(saveShortcut.hint)/\(superSaveShortcut.hint): save  •  Tab: focus  •  Esc: cancel")
                .foregroundStyle(NotesPalette.muted)
        }
        .foregroundStyle(NotesPalette.foreground)
        .frame(width: 58, alignment: .topLeading)
        .border(.single, color: NotesPalette.border)
    }
}
