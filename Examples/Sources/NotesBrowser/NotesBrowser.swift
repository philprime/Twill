import Twill

@main
struct NotesBrowser {
    @MainActor
    static func main() async throws {
        try await Twill.Application(
            rootView: NotesBrowserView()
                .foregroundStyle(NotesPalette.foreground)
                .tint(NotesPalette.accent)
        ).run()
    }
}
