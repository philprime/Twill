import Twill

struct ContentView: View {
    private enum Gallery: Hashable { case colors, borders, progress }
    @State private var selection = Gallery.colors

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            TabView(selection: $selection) {
                Tab("Colors", value: Gallery.colors) { ColorGrid() }
                Tab("Borders", value: Gallery.borders) { BorderGallery() }
                Tab("Progress", value: Gallery.progress) { ProgressGallery() }
            }
            Text("Left/Right: select tab · Tab/Down: content · Shift-Tab: tab bar")
            Text("Ctrl-PageUp/PageDown: switch tabs from content")
        }
    }
}
