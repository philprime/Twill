import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Split pane terminal interaction")
@MainActor
struct SplitViewApplicationTests {
    @Test(
        "Narrow pane clipping does not redefine focus traversal and restores terminal settings", .timeLimit(.minutes(1))
    )
    func clippedPanes() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activated: [Int] = []
        let application = Application(
            rootView: SplitView(leadingWidth: .fixed(4), trailingWidth: .flexible(minimum: 3)) {
                Button("L") { activated.append(1) }
            } trailing: {
                Button("R") { activated.append(2) }
            }
            .frame(width: 2, height: 2, alignment: .topLeading),
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
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(activated == [1, 2])
        #expect(try terminal.snapshot() == original)
    }
}
