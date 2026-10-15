import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Terminal progress application lifecycle")
@MainActor
struct TerminalProgressApplicationTests {
    @Test("Progress is cleared and inherited modes restored on stop or cancellation", arguments: [false, true])
    func shutdown(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let application = Application(
            rootView: EmptyView(), runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.terminalProgress.state = .indeterminate
        let (started, ready) = AsyncStream<Void>.makeStream()
        runLoop.add(
            Twill.Timer(interval: .milliseconds(0)) {
                ready.yield(())
                ready.finish()
            })
        let task = Task { try await application.run() }
        for await _ in started {}

        // -- Act --
        if cancel { task.cancel() } else { application.stop() }
        try await task.value
        application.terminalProgress.state = .hidden
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(String(bytes: data, encoding: .utf8) == "\u{1B}]9;4;3\u{7}\u{1B}]9;4;0\u{7}")
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Reader failure clears active progress and restores inherited modes")
    func readerFailure() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let application = Application(
            rootView: EmptyView(), runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))),
            keyboardEventSource: DefaultKeyboardEventSource(
                inputSource: DefaultInputSource(fileDescriptor: .custom(-1)), runLoop: runLoop))
        application.terminalProgress.state = .indeterminate
        var received: TerminalError?

        // -- Act --
        do { try await application.run() } catch { received = error as? TerminalError }
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(received == .configureInput(errno: EBADF))
        #expect(String(bytes: data, encoding: .utf8) == "\u{1B}]9;4;3\u{7}\u{1B}]9;4;0\u{7}")
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }
}
