import Foundation
import Testing
import Twill

@Suite("Focused application input")
@MainActor
struct FocusApplicationTests {
    @Test("Arrow input moves between focused controls before application fallback", .timeLimit(.minutes(1)))
    func focusedInput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var activated: [String] = []
        let root = HStack {
            Text("One").focusable().onKeyPress { key in
                guard key == .enter else { return .ignored }
                activated.append("One")
                return .handled
            }
            Text("Two").focusable().onKeyPress { key in
                guard key == .enter else { return .ignored }
                activated.append("Two")
                return .handled
            }
        }
        let application = Application(
            rootView: root, runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        var applicationKeys: [KeyEvent] = []
        application.onKeyEvent = { key in
            applicationKeys.append(key)
            if key == .character("q") { application.stop() }
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x0D, 0x1B, 0x5B, 0x42, 0x0D, 0x71]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(activated == ["One", "Two"])
        #expect(applicationKeys == [.character("q")])
        #expect(data.starts(with: Data("\u{1B}[?25l\r\u{1B}[2KOne Two".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}
