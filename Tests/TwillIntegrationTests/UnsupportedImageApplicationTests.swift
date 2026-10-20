import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Unsupported image terminal presentation")
@MainActor
struct UnsupportedImageApplicationTests {
    @Test(
        "Injected unsupported capabilities render ordinary fallback without graphics commands", .timeLimit(.minutes(1)))
    func fallbackOutput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let data = Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        var actions = 0
        let application = Application(
            rootView: ImageView(try Image(pngData: data), width: 4, height: 2) {
                Button("Unsupported image") { actions += 1 }
            }, runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.terminalCapabilities = TerminalCapabilities()
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\r\u{3}".utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let bytes = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: bytes, encoding: .utf8))

        // -- Assert --
        #expect(output.contains("Unsupported image") && !output.contains("\u{1B}_G"))
        #expect(actions == 1)
        #expect(try terminal.snapshot() == original)
    }
}
