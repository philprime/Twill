import Twill

@main
struct NotesBrowser {
    @MainActor
    static func main() async throws {
        try await Twill.Application(rootView: NotesBrowserView()).run()
    }
}
