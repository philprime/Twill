import Twill

struct NoteDetailView: View {
    let note: Note
    let onBack: @MainActor () -> Void
    let onShowHelp: @MainActor () -> Void

    @State private var showsSummary = true

    var body: some View {
        HStack {
            Text(note.title)
            if showsSummary {
                Text(note.summary)
            }
            Text("[s: toggle summary | Esc: back | ?: help]")
        }
        .focusable()
        .onKeyPress { key in
            switch key {
            case .character("s"):
                showsSummary.toggle()
            case .escape:
                onBack()
            case .character("?"):
                onShowHelp()
            default:
                return .ignored
            }
            return .handled
        }
    }
}
