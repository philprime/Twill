import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Wrapped editor terminal input")
@MainActor
struct TextEditorWrappingApplicationTests {
    @Test("Visual-row input edits logical text and restores inherited terminal modes", .timeLimit(.minutes(1)))
    func wrappedEditing() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var text = "abcdef"
        var submitted = 0
        let application = Application(
            rootView: TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .wordWrapping)
                .frame(width: 4, height: 2).onSubmit { submitted += 1 },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Up reaches the previous visual row's end, not the logical line start.
                    // End remains logical. Backspace, newline and Ctrl-C finish the edit.
                    try terminal.send(Array("\u{1B}[Ax\u{1B}[F\u{7F}\r\u{3}".utf8))
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        #expect(text == "abcxde\n")
        #expect(submitted == 0)
        #expect(output.contains("abc") && output.contains("def"))
        #expect(!output.contains("abcdef"))
        #expect(try terminal.snapshot() == original)
    }
}
