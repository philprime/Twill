import Twill

struct ContentView: View {
    @State private var colorsExpanded = false
    @State private var bordersExpanded = false
    @State private var progressExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Arrows: focus • Enter/Space: expand or collapse")
            DisclosureGroup("Colors", isExpanded: $colorsExpanded) {
                ColorGrid()
            }
            DisclosureGroup("Borders", isExpanded: $bordersExpanded) {
                BorderGallery()
            }
            DisclosureGroup("Progress", isExpanded: $progressExpanded) {
                ProgressGallery()
            }
        }
    }
}
