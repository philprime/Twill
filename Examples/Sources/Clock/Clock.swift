import Twill

@main
struct Clock {
    @MainActor
    static func main() async throws {
        try await Twill.Application(rootView: ClockView()).run()
    }
}
