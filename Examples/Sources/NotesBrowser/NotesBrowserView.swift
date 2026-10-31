import Foundation
import Twill

struct NotesBrowserView: View {
    @State private var notes = Note.examples
    // Selection belongs to the browser, not to the list's keyboard focus.
    @State private var selectedNoteID: Note.ID?
    @State private var query = ""
    @State private var isHelpPresented = false
    @State private var isCreatePresented = false
    @State private var editingNote: Note?
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var deletingNote: Note?

    private var matchingNotes: [Note] {
        notes.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedNote: Note? {
        SelectionPolicy.firstVisible.resolve(in: matchingNotes, selection: selectedNoteID)
    }

    var body: some View {
        let matches = matchingNotes
        let previewNote = SelectionPolicy.firstVisible.resolve(in: matches, selection: selectedNoteID)
        return VStack {
            Text(" Notes  \(notes.count) in memory ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(NotesPalette.background)
                .backgroundStyle(.tint)
            GroupBox("Search") {
                TextField("Search titles and bodies", text: $query)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(NotesPalette.foreground)
            }
            .foregroundStyle(NotesPalette.border)
            SplitView(leadingWidth: .fixed(28), spacing: 2) {
                GroupBox("Notes") {
                    NoteListView(notes: matches, selectedNoteID: $selectedNoteID, onDelete: requestDeletion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .foregroundStyle(NotesPalette.foreground)
                }
                .foregroundStyle(NotesPalette.border)
            } trailing: {
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
            StatusBar {
                Text(" Tab: focus  •  Arrows: scroll/select  •  e: edit  •  n: new  •  d: delete  •  ?: help ")
            }
            .foregroundStyle(.tint)
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
                draftTitle = selectedNote.title
                draftBody = selectedNote.body
                editingNote = selectedNote
            default:
                return .ignored
            }
            return .handled
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView()
        }
        .sheet(isPresented: $isCreatePresented) { dismiss in
            NoteEditorView(
                title: $draftTitle,
                noteText: $draftBody,
                heading: "New note",
                saveLabel: "Create note",
                onSave: createNote,
                onCancel: dismiss.callAsFunction)
        }
        .sheet(item: $editingNote) { note, dismiss in
            NoteEditorView(
                title: $draftTitle,
                noteText: $draftBody,
                heading: "Edit note",
                saveLabel: "Save changes",
                onSave: { saveNote(note.id) },
                onCancel: dismiss.callAsFunction)
        }
        .confirmationDialog("Delete note?", item: $deletingNote) { note in
            Button("Delete note", role: .destructive) { deleteNote(note.id) }
            Button("Keep note", role: .cancel) {}
        } message: { note in
            Text("Remove \(note.title) from this in-memory session?")
        }
    }

    private func requestDeletion(_ id: Note.ID) {
        deletingNote = notes.first { $0.id == id }
    }

    private func saveNote(_ id: Note.ID) {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
            let index = notes.firstIndex(where: { $0.id == id })
        else { return }
        notes[index].title = title
        notes[index].body = draftBody
        editingNote = nil
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
