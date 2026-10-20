import Twill

struct ContentView: View {
    private enum Gallery: Hashable {
        case colors, borders, progress, outline

        var title: String {
            switch self {
            case .colors: "Colors"
            case .borders: "Borders"
            case .progress: "Progress"
            case .outline: "Outline"
            }
        }
    }

    private enum GalleryCommand: Hashable { case expand, collapse }

    private struct GalleryState: Identifiable {
        let id: Gallery
        var isExpanded: Bool
    }

    @State private var isPalettePresented = false
    @State private var selection = Gallery.colors
    @State private var galleries = [
        GalleryState(id: .colors, isExpanded: false),
        GalleryState(id: .borders, isExpanded: false),
        GalleryState(id: .progress, isExpanded: true),
        GalleryState(id: .outline, isExpanded: true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Menu("Gallery actions") {
                Menu("Visibility") {
                    Button(expandCommand)
                    Divider()
                    Button(collapseCommand)
                }
            }
            TabView(selection: $selection) {
                ForEach($galleries) { gallery in
                    let kind = gallery.wrappedValue.id
                    Tab(kind.title, value: kind) {
                        DisclosureGroup(kind.title, isExpanded: gallery.isExpanded) {
                            content(for: kind)
                        }
                    }
                }
            }
            Text("Left/Right: select tab · Tab/Down: content · Shift-Tab: tab bar")
            Text("Ctrl-PageUp/PageDown: switch tabs from content · Ctrl-P: command palette")
            Text("Enter/Space: expand or collapse gallery · Gallery actions: Enter to open, Esc to dismiss")
        }
        .commandPalette(isPresented: $isPalettePresented, commands: [expandCommand, collapseCommand])
        .onKeyPress { key in
            guard key == .controlP else { return .ignored }
            isPalettePresented = true
            return .handled
        }
    }

    private var expandCommand: Command<GalleryCommand> {
        Command(
            .expand, title: "Expand all", isEnabled: galleries.contains { !$0.isExpanded },
            shortcuts: [KeyboardShortcut(.e)], action: { setExpanded(true) })
    }

    private var collapseCommand: Command<GalleryCommand> {
        Command(
            .collapse, title: "Collapse all", isEnabled: galleries.contains { $0.isExpanded },
            shortcuts: [KeyboardShortcut(.c)], action: { setExpanded(false) })
    }

    @ViewBuilder
    private func content(for gallery: Gallery) -> some View {
        switch gallery {
        case .colors: ColorGrid()
        case .borders: BorderGallery()
        case .progress: ProgressGallery()
        case .outline: OutlineGallery()
        }
    }

    private func setExpanded(_ expanded: Bool) {
        for index in galleries.indices {
            $galleries[index].isExpanded.wrappedValue = expanded
        }
    }
}
