import Twill

@main
struct Keyboard {
    @MainActor
    static func main() async throws {
        let application = Twill.Application(rootView: EmptyView())
        print("Press keys to inspect events. Press p to toggle terminal progress. Press q or Ctrl-C to quit.")
        print("The native progress indicator appears in supported terminal emulators, outside the text area.")

        application.onKeyEvent = { [weak application] key in
            guard let application else { return }
            print(String(describing: key))
            if key == .p {
                let progress = application.terminalProgress
                progress.state = progress.state == .hidden ? .indeterminate : .hidden
                print(progress.state == .hidden ? "Terminal progress hidden." : "Terminal progress active.")
            } else if key == .q {
                application.stop()
            }
        }
        try await application.run()
    }
}
