import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Timeline application presentation")
@MainActor
struct TimelineApplicationTests {
    @Test(
        "A 20 Hz timeline renders through a pipe and restores the terminal",
        .timeLimit(.minutes(1)), arguments: [false, true])
    func updatesAndRestores(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var frames = 0
        let root = TimelineView(.periodic(from: .now, by: 0.05)) { _ -> Text in
            MainActor.assertIsolated()
            frames += 1
            continuation.yield(())
            continuation.finish()
            return Text("Frame \(frames)")
        }
        let application = Application(
            rootView: root,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        let task = Task { try await application.run() }
        defer { task.cancel() }
        for await _ in ready {}

        // -- Act --
        try await Task.sleep(for: .milliseconds(160))
        if cancel { task.cancel() } else { application.stop() }
        try await task.value
        let framesAtShutdown = frames
        try await Task.sleep(for: .milliseconds(80))
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(frames >= 2)
        #expect(frames == framesAtShutdown)
        #expect(text.hasPrefix("\u{1B}[?25l\r\u{1B}[2KFrame 1"))
        #expect(text.contains("\r\u{1B}[6C2"))
        #expect(text.hasSuffix("\n\u{1B}[?25h"))
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Sibling timelines share presentation and Ctrl-C restores the terminal", .timeLimit(.minutes(1)))
    func siblingPresentation() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let start = Date.now
        var fast = 0
        var slow = 0
        let root = HStack {
            TimelineView(.periodic(from: start, by: 0.05)) { _ -> Text in
                fast += 1
                if fast == 3 {
                    do { try terminal.send([0x03]) } catch { Issue.record(error) }
                }
                return Text("Fast \(fast)")
            }
            // A long period keeps the assertion independent of subsecond CI scheduling.
            TimelineView(.periodic(from: start, by: 60)) { _ -> Text in
                slow += 1
                return Text("Slow \(slow)")
            }
        }
        let application = Application(
            rootView: root,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(fast >= 3)
        #expect(slow == 1)
        #expect(text.contains("\r\u{1B}[2KFast 1 Slow 1"))
        #expect(text.contains("\r\u{1B}[5C3"))
        #expect(text.hasSuffix("\n\u{1B}[?25h"))
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Initial output failure restores terminal settings", .timeLimit(.minutes(1)))
    func outputFailure() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let application = Application(
            rootView: Text("Clock"),
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                // An open read-only descriptor fails writes without descriptor-reuse races or SIGPIPE.
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
            )
        )
        var receivedError: Error?

        // -- Act --
        do { try await application.run() } catch { receivedError = error }
        try pipe.fileHandleForWriting.close()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(receivedError != nil)
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }
}
