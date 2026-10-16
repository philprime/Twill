import Twill

struct ContentView: View {
    private enum Gallery: Hashable { case colors, borders, progress, outline }
    @State private var selection = Gallery.colors
    @State private var colorsExpanded = false
    @State private var bordersExpanded = false
    @State private var progressExpanded = true
    @State private var outlineExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Menu(
                "Gallery actions",
                items: [
                    MenuItem(
                        "Expand all", shortcut: MenuShortcut(.e, hint: "e"),
                        isEnabled: !colorsExpanded || !bordersExpanded || !progressExpanded || !outlineExpanded
                    ) {
                        colorsExpanded = true
                        bordersExpanded = true
                        progressExpanded = true
                        outlineExpanded = true
                    },
                    MenuItem(
                        "Collapse all", shortcut: MenuShortcut(.c, hint: "c"),
                        isEnabled: colorsExpanded || bordersExpanded || progressExpanded || outlineExpanded
                    ) {
                        colorsExpanded = false
                        bordersExpanded = false
                        progressExpanded = false
                        outlineExpanded = false
                    },
                ])
            TabView(selection: $selection) {
                Tab("Colors", value: Gallery.colors) {
                    DisclosureGroup("Colors", isExpanded: $colorsExpanded) { ColorGrid() }
                }
                Tab("Borders", value: Gallery.borders) {
                    DisclosureGroup("Borders", isExpanded: $bordersExpanded) { BorderGallery() }
                }
                Tab("Progress", value: Gallery.progress) {
                    DisclosureGroup("Progress", isExpanded: $progressExpanded) { ProgressGallery() }
                }
                Tab("Outline", value: Gallery.outline) {
                    DisclosureGroup("Outline", isExpanded: $outlineExpanded) { OutlineGallery() }
                }
            }
            Text("Left/Right: select tab · Tab/Down: content · Shift-Tab: tab bar")
            Text("Ctrl-PageUp/PageDown: switch tabs from content")
            Text("Enter/Space: expand or collapse gallery · Gallery actions: Enter to open, Esc to dismiss")
        }
    }
}
