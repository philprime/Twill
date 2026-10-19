import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Spacer and Divider terminal interaction")
@MainActor
struct SpacerDividerApplicationTests {
    @Test("Space and separators add no focus stops and restore inherited terminal modes", .timeLimit(.minutes(1)))
    func controlTraversal() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activated: [Int] = []
        let application = Application(
            rootView: HStack(spacing: 0) {
                Button("One") { activated.append(1) }
                Spacer(minLength: 1)
                Divider()
                Button("Two") { activated.append(2) }
            }.frame(width: 16),
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\r\t\r\u{3}".utf8)) } catch {
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
        #expect(activated == [1, 2])
        #expect(output.contains("│"))
        #expect(try terminal.snapshot() == original)
    }
}
