import Foundation
import Twill

struct NotesBrowserView: View {
    @State private var notes = Note.examples
    // Selection belongs to the browser, not to the list's keyboard focus.
    @State private var selectedNoteID: Note.ID?
    @State private var query = ""
    @State private var isHelpPresented = false
    @State private var isCreatePresented = false
    @State private var isEditPresented = false
    @State private var editingNoteID: Note.ID?
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var isDeletePresented = false
    @State private var deletingNoteID: Note.ID?

    private var matchingNotes: [Note] {
        notes.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedNote: Note? {
        let matches = matchingNotes
        return matches.first { $0.id == selectedNoteID } ?? matches.first
    }

    var body: some View {
        let matches = matchingNotes
        let previewNote = matches.first { $0.id == selectedNoteID } ?? matches.first
        return VStack {
            Text(" Notes  \(notes.count) in memory ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(NotesPalette.background)
                .backgroundStyle(NotesPalette.accent)
            GroupBox("Search") {
                TextField("Search titles and bodies", text: $query)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(NotesPalette.foreground)
            }
            .foregroundStyle(NotesPalette.border)
            HStack(spacing: 2) {
                GroupBox("Notes") {
                    NoteListView(notes: matches, selectedNoteID: $selectedNoteID, onDelete: requestDeletion)
                        .frame(width: 26)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .foregroundStyle(NotesPalette.foreground)
                }
                .foregroundStyle(NotesPalette.border)
                if let previewNote {
                    GroupBox("Preview") {
                        ScrollView {
                            NoteDetailView(note: previewNote)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .foregroundStyle(NotesPalette.foreground)
                    }
                    .foregroundStyle(NotesPalette.border)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(" Tab: focus  •  Arrows: scroll/select  •  e: edit  •  n: new  •  d: delete  •  ?: help ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(NotesPalette.accent)
        }
        .backgroundStyle(NotesPalette.background)
        .onKeyPress { key in
            // An editing field consumes printable keys before they reach these shortcuts.
            switch key {
            case .questionMark:
                isHelpPresented = true
            case .n:
                draftTitle = ""
                draftBody = ""
                isCreatePresented = true
            case .e:
                guard let selectedNote else { return .ignored }
                editingNoteID = selectedNote.id
                draftTitle = selectedNote.title
                draftBody = selectedNote.body
                isEditPresented = true
            default:
                return .ignored
            }
            return .handled
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView(onDismiss: { isHelpPresented = false })
        }
        .sheet(isPresented: $isCreatePresented) {
            NoteEditorView(
                title: $draftTitle,
                noteText: $draftBody,
                heading: "New note",
                saveLabel: "Create note",
                onSave: createNote,
                onCancel: { isCreatePresented = false })
        }
        .sheet(isPresented: $isEditPresented) {
            NoteEditorView(
                title: $draftTitle,
                noteText: $draftBody,
                heading: "Edit note",
                saveLabel: "Save changes",
                onSave: saveNote,
                onCancel: { isEditPresented = false })
        }
        .confirmationDialog("Delete note?", isPresented: $isDeletePresented) {
            Button("Delete note", role: .destructive) {
                if let deletingNoteID { deleteNote(deletingNoteID) }
                deletingNoteID = nil
            }
            Button("Keep note", role: .cancel) { deletingNoteID = nil }
        } message: {
            Text("This removes the note from this in-memory session.")
        }
    }

    private func requestDeletion(_ id: Note.ID) {
        deletingNoteID = id
        isDeletePresented = true
    }

    private func saveNote() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let editingNoteID,
            let index = notes.firstIndex(where: { $0.id == editingNoteID })
        else { return }
        notes[index].title = title
        notes[index].body = draftBody
        isEditPresented = false
    }

    private func deleteNote(_ id: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes.remove(at: index)
        if selectedNoteID == id {
            selectedNoteID = matchingNotes.first?.id
        }
    }

    private func createNote() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let note = Note(id: UUID().uuidString, title: title, body: draftBody)
        notes.insert(note, at: 0)
        query = ""
        selectedNoteID = note.id
        isCreatePresented = false
    }
}
