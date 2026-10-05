import Foundation
import Twill

struct FilePreviewView: View {
    let preview: FilePreview
    let name: String
    @State private var line = 0
    @State private var pendingG = false

    private var supportsImages: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["TERM_PROGRAM"] == "ghostty" || environment["TERM"] == "xterm-kitty"
            || environment["TERM"] == "xterm-ghostty"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(name) (read-only)").foregroundStyle(Color.ansi(.yellow))
            switch preview {
            case .image(let image):
                if supportsImages {
                    ImageView(image, width: 40, height: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text("PNG preview requires Ghostty or Kitty. Terminal capability probing is not yet supported.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
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
                proxy.scrollTo(line)
                return .handled
            }
        }
    }
}
