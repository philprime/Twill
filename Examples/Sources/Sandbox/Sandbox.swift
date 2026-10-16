import Twill

@main
struct Sandbox {
    @MainActor
    static func main() async throws {
        let application = Twill.Application(rootView: ContentView())
        try await application.run()
    }
}
