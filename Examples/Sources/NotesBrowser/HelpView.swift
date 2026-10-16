import Twill

struct HelpView: View {
    let onDismiss: @MainActor () -> Void

    var body: some View {
        VStack {
            Text("Help")
                .foregroundStyle(NotesPalette.accent)
            Text("Tab / Shift-Tab: switch search, list, and detail")
            Text("Arrows: navigate list or scroll the preview")
            Text("Enter: select a note or start/finish editing a field")
            Text("e: edit selected note | n: create | d: delete focused note")
            Text("?: help")
            Text("Esc: stop editing or close a sheet")
            Text("Changes are in memory only and disappear when you quit")
        }
        .foregroundStyle(NotesPalette.foreground)
        .border(.single, color: NotesPalette.border)
        .focusable()
        .onKeyPress { key in
            guard key == .escape else { return .ignored }
            onDismiss()
            return .handled
        }
    }
}
