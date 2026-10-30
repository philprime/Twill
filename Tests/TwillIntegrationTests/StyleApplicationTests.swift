import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Contextual terminal styles")
@MainActor
struct StyleApplicationTests {
    @Test(
        "Nested tint and foreground hierarchy encode independently and restore terminal modes", .timeLimit(.minutes(1)))
    func contextualOutput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let application = Application(
            rootView: HStack(spacing: 0) {
                Text("A")
                Text("B").foregroundStyle(.secondary).tint(.green)
                Text("C").foregroundStyle(.primary)
            }.foregroundStyle(.tint).backgroundStyle(Color.blue).bold().focusable().tint(.red),
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
        #expect(output.contains("\u{1B}[31m\u{1B}[44m\u{1B}[1m\u{1B}[7mA"))
        #expect(output.contains("\u{1B}[32m\u{1B}[2mB"))
        #expect(output.contains("\u{1B}[31m\u{1B}[22;1mC"))
        #expect(try terminal.snapshot() == original)
    }
}
