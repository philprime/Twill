import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Aligned terminal text")
@MainActor
struct MultilineTextAlignmentApplicationTests {
    @Test(
        "Aligned wide and combining glyphs reach the terminal and inherited modes are restored",
        .timeLimit(.minutes(1)))
    func alignedOutput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let application = Application(
            rootView: Text("ABCD\n界\ne\u{301}").multilineTextAlignment(.trailing),
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
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
        #expect(data.contains(Data("ABCD".utf8)))
        #expect(data.contains(Data("  界".utf8)))
        #expect(data.contains(Data("   e\u{301}".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}
