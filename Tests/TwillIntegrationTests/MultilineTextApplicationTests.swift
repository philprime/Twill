import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Multiline terminal presentation")
@MainActor
struct MultilineTextApplicationTests {
    @Test(
        "Wrapped sanitized text reaches a real terminal session and restores inherited modes", .timeLimit(.minutes(1)))
    func multilineOutput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let application = Application(
            rootView: Text("one two\nA\u{1B}[2J\n界e\u{301}").lineBreakMode(.wordWrapping).frame(width: 4),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x03]) } catch {
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
        #expect(data.contains(Data("one ".utf8)))
        #expect(data.contains(Data("two ".utf8)))
        #expect(data.contains(Data("[2J ".utf8)))
        #expect(data.contains(Data("界e\u{301} ".utf8)))
        #expect(!data.contains(Data("\u{1B}[2J".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}
