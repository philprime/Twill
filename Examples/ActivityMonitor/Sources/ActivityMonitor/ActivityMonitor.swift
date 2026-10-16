import Foundation
import Twill

@main
struct ActivityMonitor {
    @MainActor
    static func main() async throws {
        if CommandLine.arguments.contains("--help") {
            print("Usage: ActivityMonitor\nRead-only system monitor. Tab: focus, arrows: select/sort, Ctrl-C: quit.")
            return
        }
        let application = Twill.Application(rootView: ActivityMonitorView())
        try await application.run()
    }
}
