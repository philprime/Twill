import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Secure field application input")
@MainActor
struct SecureFieldApplicationTests {
    @Test("Terminal output masks the value while editing and submission retain it", .timeLimit(.minutes(1)))
    func secureEditingRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var text = "s3cr界"
        var submissions: [String] = []
        let application = Application(
            rootView: SecureField("Password", text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submissions.append(text) },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        application.options.ui.mode = .inline
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Move before the wide character, insert, delete, reinsert, submit, and quit.
                    try terminal.send([0x1B, 0x5B, 0x44, 0x78, 0x7F, 0x78, 0x0D, 0x03])
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
        #expect(text == "s3crx界")
        #expect(submissions == ["s3crx界"])
        #expect(output.contains("•••••"))
        #expect(!output.contains("s3cr"))
        #expect(!output.contains("界"))
        #expect(!output.contains("x"))
        #expect(output.hasSuffix("\u{1B}[?25h"))
        #expect(try terminal.snapshot() == original)
    }
}
