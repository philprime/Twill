import Foundation
import Twill

struct FileBrowserView: View {
    @State private var directory: URL
    @State private var entries: [FileEntry] = []
    @State private var selected = 0
    @State private var showHidden = false
    @State private var message = ""
    @State private var preview: FilePreview?
    @State private var previewName = ""
    @State private var pendingG = false

    init(directory: URL) {
        _directory = State(wrappedValue: directory.standardizedFileURL)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(directory.path)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.ansi(.cyan))
            if let preview {
                FilePreviewView(preview: preview, name: previewName)
                    .onKeyPress { key in
                        switch key {
                        case .q, .h, .escape, .arrowLeft, .backspace:
                            self.preview = nil
                            return .handled
                        default: return .ignored
                        }
                    }
            } else {
                ForEach([directory.path], id: \.self) { _ in
                    directoryList
                }
            }
            Text(
                message.isEmpty
                    ? "h: parent  j/k: select  l/Enter: open  gg/G: first/last  .: hidden  r: reload  q: quit" : message
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { reload() }
    }

    private var directoryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    if entries.isEmpty { Text("(empty directory)") }
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let marker = index == selected ? ">" : " "
                        let suffix = entry.isDirectory ? "/" : ""
                        Text("\(marker) \(entry.url.lastPathComponent)\(suffix)")
                            .foregroundStyle(index == selected ? Color.ansi(.cyan) : Color.ansi(.white))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onKeyPress { key in
                let wasG = pendingG
                pendingG = key == .g && !wasG
                switch key {
                case .j, .arrowDown: selected = min(max(0, entries.count - 1), selected + 1)
                case .k, .arrowUp: selected = max(0, selected - 1)
                case .G, .end: selected = max(0, entries.count - 1)
                case .g:
                    if wasG { selected = 0 }
                case .home: selected = 0
                case .h, .arrowLeft, .backspace: goToParent()
                case .l, .arrowRight, .enter: openSelection()
                case .period:
                    showHidden.toggle()
                    reload()
                case .r: reload()
                default: return .ignored
                }
                if entries.indices.contains(selected) {
                    proxy.scrollTo(entries[selected].id)
                }
                return .handled
            }
            .task {
                if entries.indices.contains(selected) { proxy.scrollTo(entries[selected].id) }
            }
        }
    }

    private func reload(selecting url: URL? = nil) {
        do {
            let loaded = try FileEntry.contents(of: directory, showHidden: showHidden)
            entries = loaded
            selected = url.flatMap { target in loaded.firstIndex { $0.url == target } } ?? 0
            message = ""
        } catch {
            entries = []
            selected = 0
            message = error.localizedDescription
        }
    }

    private func goToParent() {
        let previous = directory
        let parent = directory.deletingLastPathComponent()
        guard parent != directory else { return }
        directory = parent
        reload(selecting: previous)
    }

    private func openSelection() {
        guard entries.indices.contains(selected) else { return }
        let entry = entries[selected]
        if entry.isDirectory {
            // Leave the current directory usable if the destination is unreadable.
            do {
                let loaded = try FileEntry.contents(of: entry.url, showHidden: showHidden)
                directory = entry.url
                entries = loaded
                selected = 0
                message = ""
            } catch { message = error.localizedDescription }
        } else {
            do {
                preview = try FilePreview.load(entry.url)
                previewName = entry.url.lastPathComponent
                message = ""
            } catch { message = error.localizedDescription }
        }
    }
}
