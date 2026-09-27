import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Terminal viewport observation")
@MainActor
struct TerminalViewportTests {
    @Test("Viewport reads real pseudo-terminal dimensions without altering modes")
    func readsDimensions() throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let viewport = DefaultTerminalViewport(fileDescriptor: .custom(terminal.fileDescriptor))
        try resize(terminal, columns: 80, rows: 24)

        // -- Act --
        let initial = try viewport.size()
        try resize(terminal, columns: 36, rows: 12)
        let changed = try viewport.size()

        // -- Assert --
        #expect(initial == TerminalSize(columns: 80, rows: 24))
        #expect(changed == TerminalSize(columns: 36, rows: 12))
        #expect(try terminal.snapshot() == original)
    }

    @Test("SIGWINCH delivers a resize on the UI actor", .timeLimit(.minutes(1)))
    func resizeSignal() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try resize(terminal, columns: 80, rows: 24)
        let viewport = DefaultTerminalViewport(fileDescriptor: .custom(terminal.fileDescriptor))
        let initial = try viewport.start()
        var iterator = viewport.events.makeAsyncIterator()
        // Wait for the registration snapshot before explicitly exercising SIGWINCH.
        _ = try await iterator.next()

        // -- Act --
        try resize(terminal, columns: 50, rows: 10)
        #expect(kill(getpid(), SIGWINCH) == 0)
        var observed: TerminalSize?
        do {
            // Other process-wide resize signals can leave an older size queued.
            while let size = try await iterator.next() {
                MainActor.assertIsolated()
                if size == TerminalSize(columns: 50, rows: 10) {
                    observed = size
                    break
                }
            }
        } catch {
            await viewport.stop()
            throw error
        }
        await viewport.stop()

        // -- Assert --
        #expect(initial == TerminalSize(columns: 80, rows: 24))
        #expect(observed == TerminalSize(columns: 50, rows: 10))
    }

    @Test(
        "A running application redraws on resize and restores inherited modes", .timeLimit(.minutes(1)),
        arguments: [false, true])
    func applicationResize(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        try resize(terminal, columns: 3, rows: 2)
        let pipe = Pipe()
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        let application = Application(
            rootView: Text("ABCDEF"),
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            ),
            terminalViewport: DefaultTerminalViewport(fileDescriptor: .custom(terminal.fileDescriptor))
        )
        application.options.ui.mode = .inline
        reader.start()
        let task = Task { try await application.run() }
        defer { task.cancel() }
        var output = ""
        var requestedResize = false

        // -- Act --
        do {
            for try await bytes in reader.events {
                output += try #require(String(bytes: bytes, encoding: .utf8))
                if !requestedResize, output.contains("\r\u{1B}[2KABC") {
                    requestedResize = true
                    try resize(terminal, columns: 6, rows: 4)
                    #expect(kill(getpid(), SIGWINCH) == 0)
                }
                if output.contains("\r\u{1B}[2KABCDEF") { break }
            }
            if cancel { task.cancel() } else { application.stop() }
            try await task.value
        } catch {
            task.cancel()
            _ = await task.result
            await reader.stop()
            throw error
        }
        await reader.stop()

        // -- Assert --
        #expect(requestedResize)
        #expect(output.hasPrefix("\u{1B}[?25l\r\u{1B}[2KABC"))
        #expect(output.contains("\r\u{1B}[2KABCDEF"))
        #expect(try terminal.snapshot() == original)
    }

    @Test("Viewport setup failure restores the terminal", .timeLimit(.minutes(1)))
    func viewportFailure() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let application = Application(
            rootView: Text("Clock"),
            terminalSession: DefaultTerminalSession(fileDescriptor: .custom(terminal.fileDescriptor)),
            terminalViewport: DefaultTerminalViewport(fileDescriptor: .custom(-1))
        )
        var received: TerminalError?

        // -- Act --
        do { try await application.run() } catch { received = error as? TerminalError }

        // -- Assert --
        #expect(received == .readSize(errno: EBADF))
        #expect(try terminal.snapshot() == original)
    }

    @Test("Piped output is unconstrained and invalid descriptors report their failure")
    func nonTerminalOutput() throws {
        // -- Arrange --
        let pipe = Pipe()
        let viewport = DefaultTerminalViewport(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
        let invalid = DefaultTerminalViewport(fileDescriptor: .custom(-1))

        // -- Act --
        let size = try viewport.size()
        let result = Result { try invalid.size() }

        // -- Assert --
        #expect(size == nil)
        if case .failure(let error) = result {
            #expect(error as? TerminalError == .readSize(errno: EBADF))
        } else {
            Issue.record("Expected an invalid-descriptor error")
        }
    }

    private func resize(_ terminal: TestTerminal, columns: UInt16, rows: UInt16) throws {
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        guard ioctl(terminal.fileDescriptor, UInt(TIOCSWINSZ), &size) == 0 else {
            throw TestApplicationError.systemCall(operation: "TIOCSWINSZ", code: errno)
        }
    }
}
