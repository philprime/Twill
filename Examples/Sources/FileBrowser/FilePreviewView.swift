import Foundation
import Twill

struct FilePreviewView: View {
    let preview: FilePreview
    let name: String
    @State private var line = 0
    @State private var pendingG = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(name) (read-only)").foregroundStyle(Color.ansi(.yellow))
            switch preview {
            case .image(let image):
                ImageView(image, width: 40, height: 20) {
                    ContentUnavailableView(
                        "Image unavailable", description: "PNG graphics are not enabled for this terminal.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .text(let lines):
                textPreview(lines)
            }
            Text("j/k: scroll  Ctrl-D/U: 20 lines  gg/G: first/last  h/Escape/q: back")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func textPreview(_ lines: [String]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, text in
                        Text(text.replacingOccurrences(of: "\t", with: "    "))
                    }
                }
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onKeyPress { key in
                let wasG = pendingG
                pendingG = key == .g && !wasG
                switch key {
                case .j, .arrowDown: line += 1
                case .k, .arrowUp: line -= 1
                case .controlD, .pageDown: line += 20
                case .control(0x15), .pageUp: line -= 20
                case .g:
                    if wasG { line = 0 }
                case .G, .end: line = lines.count - 1
                case .home: line = 0
                default: return .ignored
                }
                line = min(max(0, line), max(0, lines.count - 1))
                let anchor: ScrollViewProxy.Anchor = key == .home || key == .end ? .nearest : .top
                proxy.scrollTo(line, anchor: anchor)
                return .handled
            }
        }
    }
}
