import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Attributed terminal presentation")
@MainActor
struct TextAttributeApplicationTests {
    @Test("Attributes reset independently of colors and focus before terminal restoration", .timeLimit(.minutes(1)))
    func attributedOutput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let application = Application(
            rootView: HStack(spacing: 0) {
                Text("A").textAttributes([.bold, .dim, .italic, .underline])
                Text("B").bold()
                Text("C")
            }.foregroundStyle(Color.red).focusable(),
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(Twill.Timer(interval: .milliseconds(1)) { application.stop() })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        #expect(output.contains("\u{1B}[1;2;3;4m\u{1B}[7mA"))
        #expect(output.contains("\u{1B}[22;1;23;24mB\u{1B}[22mC"))
        #expect(output.contains("\u{1B}[27m\u{1B}[39m"))
        #expect(try terminal.snapshot() == original)
    }
}
