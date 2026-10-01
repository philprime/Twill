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

    private var matchingNotes: [Note] {
        notes.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedNote: Note? {
        matchingNotes.first { $0.id == selectedNoteID } ?? matchingNotes.first
    }

    var body: some View {
        VStack {
            Text(" Notes  \(notes.count) in memory ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(NotesPalette.background)
                .backgroundStyle(NotesPalette.accent)
            ScrollView {
                TextField("Search titles and bodies", text: $query)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 1)
            .foregroundStyle(NotesPalette.foreground)
            .border(.single, color: NotesPalette.border)
            HStack(spacing: 2) {
                ScrollView {
                    NoteListView(notes: matchingNotes, selectedNoteID: $selectedNoteID, onDelete: deleteNote)
                }
                .frame(width: 26)
                .frame(maxHeight: .infinity, alignment: .top)
                .border(.single, color: NotesPalette.border)
                if let selectedNote {
                    ScrollView {
                        NoteDetailView(note: selectedNote)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .border(.single, color: NotesPalette.border)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(" Tab: pane  •  Arrows: scroll/select  •  e: edit  •  n: new  •  d: delete  •  ?: help ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(NotesPalette.accent)
        }
        .backgroundStyle(NotesPalette.background)
        .onKeyPress { key in
            // An editing field consumes printable keys before they reach these shortcuts.
            switch key {
            case .character("?"):
                isHelpPresented = true
            case .character("n"):
                draftTitle = ""
                draftBody = ""
                isCreatePresented = true
            case .character("e"):
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
