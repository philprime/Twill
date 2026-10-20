import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Endpoint editing application input")
@MainActor
struct TextFieldEditingKeyApplicationTests {
    @ViewBuilder
    private func field(secure: Bool, text: Binding<String>) -> some View {
        if secure { SecureField("Password", text: text) } else { TextField("Value", text: text) }
    }

    @Test(
        "Real terminal endpoint/delete sequences preserve graphemes and secure output",
        .timeLimit(.minutes(1)), arguments: [false, true])
    func editingKeys(secure: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let initial = "A界e\u{301}👩‍💻Z"
        var text = initial
        var submitted: [String] = []
        let application = Application(
            rootView: field(secure: secure, text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submitted.append(text) },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Delete the first, last, then first remaining grapheme. Submit and exit.
                    try terminal.send(Array("\u{1B}[H\u{1B}[3~\u{1B}[F\u{1B}[D\u{1B}[3~\u{1B}[H\u{1B}[3~\r\u{3}".utf8))
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
        #expect(text == "e\u{301}👩‍💻")
        #expect(submitted == [text])
        if secure {
            #expect(output.contains("•••••"))
            #expect(!output.contains(initial))
            #expect(!output.contains("界") && !output.contains("e\u{301}") && !output.contains("👩‍💻"))
        } else {
            #expect(output.contains(initial))
        }
        #expect(try terminal.snapshot() == original)
    }
}
