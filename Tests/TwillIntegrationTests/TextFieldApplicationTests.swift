import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Text field application input")
@MainActor
struct TextFieldApplicationTests {
    @Test("Rapid editing updates the binding and restores inherited terminal state", .timeLimit(.minutes(1)))
    func editingRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var committed: [String] = []
        let application = Application(
            rootView: FieldInputFixture(onCommit: {
                committed.append($0)
            }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        var applicationKeys: [KeyEvent] = []
        application.onKeyEvent = { key in
            applicationKeys.append(key)
            application.stop()
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x0D, 0x61, 0x1B, 0x5B, 0x44, 0x62, 0x0D, 0x71, 0x03]) } catch {
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
        #expect(committed == ["ba"])
        #expect(applicationKeys.isEmpty)
        #expect(data.starts(with: Data("\u{1B}[?25l\r\u{1B}[2K\u{1B}[7mSearch\u{1B}[27m".utf8)))
        #expect(data.suffix(Data("\n\u{1B}[?25h".utf8).count) == Data("\n\u{1B}[?25h".utf8))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct FieldInputFixture: View {
    @State private var text = ""
    let onCommit: @MainActor (String) -> Void

    var body: some View {
        TextField("Search", text: $text)
            .onKeyPress { key in
                guard key == .character("q") else { return .ignored }
                onCommit(text)
                return .handled
            }
    }
}
