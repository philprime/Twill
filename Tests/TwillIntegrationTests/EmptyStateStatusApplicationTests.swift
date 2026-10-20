import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Empty state and status terminal interaction")
@MainActor
struct EmptyStateStatusApplicationTests {
    @Test("Actions traverse normally while key hints remain presentation-only", .timeLimit(.minutes(1)))
    func ordinaryControls() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var actions: [String] = []
        var unhandled: [KeyEvent] = []
        let save = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.s)]) { actions.append("save") }
        let application = Application(
            rootView: VStack {
                ContentUnavailableView {
                    Text("No data")
                } description: {
                    Text("Retry when ready")
                } actions: {
                    Button("Retry") { actions.append("retry") }
                }
                StatusBar {
                    Button("Help") { actions.append("help") }
                    Spacer()
                    KeyHints([save])
                }
            }, runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { unhandled.append($0) }
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\r\t\rs\u{3}".utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(actions == ["retry", "help"])
        #expect(unhandled == [.s])
        #expect(try terminal.snapshot() == original)
    }
}
