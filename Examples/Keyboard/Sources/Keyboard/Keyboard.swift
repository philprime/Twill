import Twill

@main
struct Keyboard {
    @MainActor
    static func main() async throws {
        let application = Twill.Application()
        print("Press keys to inspect events. Press q or Ctrl-C to quit.")

        application.onKeyEvent = { [weak application] key in
            print(String(describing: key))
            if key == .character("q") {
                application?.stop()
            }
        }
        try await application.run()
    }
}
