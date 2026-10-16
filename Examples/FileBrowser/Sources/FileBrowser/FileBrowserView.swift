import Foundation
import Twill

struct FileBrowserView: View {
    @State private var directory: URL
    @State private var entries: [FileEntry] = []
    @State private var selectedID: FileEntry.ID?
    @State private var showHidden = false
    @State private var message = ""
    @State private var preview: FilePreview?
    @State private var previewName = ""
    @State private var pendingG = false

    private var selected: Int {
        get { entries.firstIndex { $0.id == selectedID } ?? 0 }
        nonmutating set { selectedID = entries.indices.contains(newValue) ? entries[newValue].id : nil }
    }

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
                ScrollView {
                    Toggle(
                        "Show hidden files",
                        isOn: Binding(
                            get: { showHidden },
                            set: {
                                showHidden = $0
                                reload()
                            }))
                }
                .frame(height: 1)
            }
            Text(
                message.isEmpty
                    ? "h: parent  j/k: select  l/Enter: open  gg/G: first/last  .: hidden  "
                        + "Tab: pane  Space: toggle  r: reload  q: quit" : message
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { reload() }
    }

    private var directoryList: some View {
        VStack(alignment: .leading) {
            if entries.isEmpty { Text("(empty directory)") }
            List(entries, selection: $selectedID) { entry in
                let suffix = entry.isDirectory ? "/" : ""
                Text("\(entry.url.lastPathComponent)\(suffix)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onSubmit { openSelection() }
            .onKeyPress { key in
                let wasG = pendingG
                pendingG = key == .g && !wasG
                switch key {
                case .j: selected = min(max(0, entries.count - 1), selected + 1)
                case .k: selected = max(0, selected - 1)
                case .G: selected = max(0, entries.count - 1)
                case .g:
                    if wasG { selected = 0 }
                case .h, .arrowLeft, .backspace: goToParent()
                case .l, .arrowRight: openSelection()
                case .period:
                    showHidden.toggle()
                    reload()
                case .r: reload()
                default: return .ignored
                }
                return .handled
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
