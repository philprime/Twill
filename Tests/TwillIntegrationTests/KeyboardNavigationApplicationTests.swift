import Testing
import Twill

@Suite("Navigation key application input")
@MainActor
struct KeyboardNavigationApplicationTests {
    @Test("Applications receive decoded navigation and unknown keys without parser changes", .timeLimit(.minutes(1)))
    func customKeys() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send([
                        0x1B, 0x5B, 0x48,
                        0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x46,
                        0x1B, 0x5B, 0x39, 0x7E,
                        0x71,
                    ])
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { key in
            keys.append(key)
            if key == .q { application.stop() }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(
            keys == [
                .home, KeyEvent(.end, modifiers: [.control]),
                KeyEvent(.unknown([0x1B, 0x5B, 0x39, 0x7E])), .q,
            ])
    }
}
