import Foundation
import Twill

@main
struct FileBrowser {
    @MainActor
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") {
            print(
                """
                Usage: FileBrowser [directory]
                Read-only browser. h/j/k/l: navigate, gg/G: first/last, Enter: open, q: back/quit.
                PNG viewing requires Ghostty or another Kitty graphics terminal. Ctrl-C always quits.
                """
            )
            return
        }
        let path = arguments.first ?? FileManager.default.currentDirectoryPath
        let view = FileBrowserView(directory: URL(fileURLWithPath: path, isDirectory: true))
        let application = Twill.Application(rootView: view)
        application.options.exitOnControlD = false
        application.onKeyEvent = { [weak application] key in
            if key == .q { application?.stop() }
        }
        try await application.run()
    }
}
