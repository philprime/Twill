import Twill

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Help").bold().underline()
                .foregroundStyle(.accent)
            Text("Tab / Shift-Tab: switch search, list, and detail")
            Text("Arrows: navigate list or scroll the preview")
            Text("Enter: select a note or start/finish editing a field")
            Text("e: edit selected note | n: create | d: delete focused note")
            Text("Home / End: field endpoints | Delete: remove next character")
            Text("Alt/Ctrl + Left/Right: words | Alt/Ctrl + Backspace/Delete: delete word")
            Text("?: help")
            Text("Esc: stop editing or close a sheet")
            Text("Changes are in memory only and disappear when you quit").dim().italic()
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.foreground)
        .border(.single, color: NotesPalette.border)
        .focusable()
    }
}
