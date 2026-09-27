import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Multi-row application presentation")
@MainActor
struct MultiRowApplicationTests {
    @Test("A multi-row view presents through a pipe and restores the borrowed terminal", .timeLimit(.minutes(1)))
    func multiRowRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let application = Application(
            rootView: VStack {
                Text("Head")
                Text("Body").focusable()
            },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
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
        let output = try #require(String(bytes: data, encoding: .utf8))

        // -- Assert --
        #expect(output.hasPrefix("\u{1B}[?1049h\u{1B}[2J\u{1B}[H\u{1B}[?25l"))
        #expect(output.contains("Head"))
        #expect(output.contains("Body"))
        #expect(output.contains("\u{1B}[7mBody\u{1B}[27m"))
        let activeScreen = try #require(output.components(separatedBy: "\u{1B}[?1049l").first)
        #expect(activeScreen.hasSuffix("\u{1B}[?25l"))
        #expect(output.hasSuffix("\u{1B}[?1049l\u{1B}[?25h"))
        #expect(try terminal.snapshot() == original)
    }
}
