import Foundation
import Twill

struct NoteEditorView: View {
    private enum Action: Hashable { case save, cancel }

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
        let save = Command(
            Action.save, title: saveLabel, isEnabled: !isTitleEmpty,
            shortcuts: [saveShortcut, superSaveShortcut], action: onSave)
        let cancel = Command(
            Action.cancel, title: "Cancel", role: .cancel,
            shortcuts: [KeyboardShortcut(.escape)], action: onCancel)
        return Form {
            FormSection(heading) {
                FormField(
                    "Title", help: "A title is required to save.",
                    validationMessage: isTitleEmpty ? "Enter a title." : nil
                ) {
                    TextField("Title", text: $title)
                        .border(.single, color: NotesPalette.border)
                }
                FormField("Body") {
                    TextEditor(text: $noteText, lineBreakMode: .wordWrapping)
                        .frame(height: 6)
                        .border(.single, color: NotesPalette.border)
                }
            }
            VStack(alignment: .leading) {
                Button(save)
                    .foregroundStyle(NotesPalette.accent)
                Button(cancel)
            }
            KeyHints([save, cancel])
                .foregroundStyle(NotesPalette.muted)
        }
        .foregroundStyle(NotesPalette.foreground)
        .frame(width: 58, alignment: .topLeading)
        .border(.single, color: NotesPalette.border)
    }
}
