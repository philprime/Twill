import Twill

struct ContentView: View {
    private enum Gallery: Hashable { case colors, borders, progress }
    @State private var selection = Gallery.colors
    @State private var colorsExpanded = false
    @State private var bordersExpanded = false
    @State private var progressExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
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
            }
            Text("Left/Right: select tab · Tab/Down: content · Shift-Tab: tab bar")
            Text("Ctrl-PageUp/PageDown: switch tabs from content")
            Text("Enter/Space: expand or collapse gallery")
        }
    }
}
