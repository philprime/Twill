import Testing

@testable import Twill

@Suite("Observation application boundaries")
@MainActor
struct ValueChangeApplicationTests {
    private final class BatchKeyboard: KeyboardEventSource {
        var onKeyEvent: (@MainActor (KeyEvent) -> Void)?
        func stop() {}
        func run() async throws {
            onKeyEvent?(.enter)
            onKeyEvent?(.a)
        }
    }

    private struct Stops: View {
        @State private var value = 0
        let stop: @MainActor () -> Void
        var body: some View {
            Button("Advance") { value += 1 }.onChange(of: value) { _, _ in stop() }
        }
    }

    @Test(
        "An observer stopping during pending input refresh prevents application key fallthrough",
        .timeLimit(.minutes(1)))
    func stopDuringInput() async throws {
        // -- Arrange --
        weak var running: Application?
        var keys: [KeyEvent] = []
        let application = Application(
            rootView: Stops(stop: { running?.stop() }), runLoop: DefaultRunLoop(),
            terminalSession: TrackingTerminalSession(output: RecordingTerminalOutput()),
            keyboardEventSource: BatchKeyboard())
        running = application
        application.onKeyEvent = { keys.append($0) }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys.isEmpty)
    }
}
