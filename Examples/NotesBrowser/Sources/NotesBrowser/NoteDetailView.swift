import Twill

struct NoteDetailView: View {
    let note: Note
    let onShowHelp: @MainActor () -> Void

    @State private var showsSummary = true

    var body: some View {
        VStack {
            Text(note.title)
                .foregroundStyle(NotesPalette.accent)
            if showsSummary {
                Text(note.summary)
                    .foregroundStyle(NotesPalette.foreground)
            }
        }
        .focusable()
        .onKeyPress { key in
            switch key {
            case .character("s"):
                showsSummary.toggle()
            case .character("?"):
                onShowHelp()
            default:
                return .ignored
            }
            return .handled
        }
    }
}
