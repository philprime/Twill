import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Keyboard application terminal lifecycle")
@MainActor
struct KeyboardApplicationTests {
    @Test("Raw input delivers keys without Enter and restores terminal state", .timeLimit(.minutes(1)))
    func keyboardRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        var running: TerminalSnapshot?
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    running = try terminal.snapshot()
                    try terminal.send([0x61, 0x1B, 0x5B, 0x41, 0xC3, 0xA9, 0x71, 0x62])
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { [weak application] key in
            MainActor.assertIsolated()
            keys.append(key)
            if key == .character("q") { application?.stop() }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        let active = try #require(running)
        #expect(active.local & tcflag_t(ICANON | ECHO | ISIG) == 0)
        #expect(active.descriptorFlags & O_NONBLOCK != 0)
        #expect(keys == [.character("a"), .arrowUp, .character("é"), .character("q")])
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Ctrl-C stops without delivering later keys and restores the terminal", .timeLimit(.minutes(1)))
    func controlC() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x61, 0x03, 0x62]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { keys.append($0) }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.character("a")])
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("An idle keyboard application restores terminal state on cancellation", .timeLimit(.minutes(1)))
    func cancellation() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                continuation.yield(())
                continuation.finish()
            })
        application.onKeyEvent = { keys.append($0) }
        let task = Task { try await application.run() }
        for await _ in ready {}
        let active = try terminal.snapshot()

        // -- Act --
        task.cancel()
        try await task.value

        // -- Assert --
        #expect(active.local & tcflag_t(ICANON | ECHO) == 0)
        #expect(keys.isEmpty)
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Lone Escape reaches the application after its deadline", .timeLimit(.minutes(1)))
    func escapeDeadline() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x1B]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { [weak application] key in
            keys.append(key)
            application?.stop()
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.escape])
    }

    @Test("A superseded Escape deadline cannot flush a newer sequence", .timeLimit(.minutes(1)))
    func supersededEscapeDeadline() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        let clock = ContinuousClock()
        var secondEscapeStarted: ContinuousClock.Instant?
        var escapeDelivered: ContinuousClock.Instant?
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x61, 0x1B]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { [weak application] key in
            keys.append(key)
            switch key {
            case .character("a"):
                runLoop.add(
                    Twill.Timer(interval: .milliseconds(30)) {
                        do { try terminal.send([0x5B, 0x41, 0x62, 0x1B]) } catch {
                            Issue.record(error)
                            application?.stop()
                        }
                    })
            case .character("b"):
                secondEscapeStarted = clock.now
            case .escape:
                escapeDelivered = clock.now
                application?.stop()
            default: break
            }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.character("a"), .arrowUp, .character("b"), .escape])
        let start = try #require(secondEscapeStarted)
        let end = try #require(escapeDelivered)
        #expect(start.duration(to: end) >= .milliseconds(45))
    }

    @Test("Already cancelled keyboard execution leaves terminal settings unchanged", .timeLimit(.minutes(1)))
    func alreadyCancelled() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let application = terminal.makeApplication()
        var keys: [KeyEvent] = []
        application.onKeyEvent = { keys.append($0) }

        // -- Act --
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await application.run()
        }
        try await task.value

        // -- Assert --
        #expect(keys.isEmpty)
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Replacing the key handler takes effect within the same input batch", .timeLimit(.minutes(1)))
    func replacesHandler() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let application = terminal.makeApplication()
        var firstHandler: [KeyEvent] = []
        var secondHandler: [KeyEvent] = []
        application.onKeyEvent = { [weak application] key in
            firstHandler.append(key)
            application?.onKeyEvent = { [weak application] next in
                secondHandler.append(next)
                application?.stop()
            }
        }
        // Queue a line before startup so it survives canonical buffering as well.
        try terminal.send([0x61, 0x62, 0x0D])

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(firstHandler == [.character("a")])
        #expect(secondHandler == [.character("b")])
    }

    @Test("Clearing the handler suppresses later keys but keeps Ctrl-C shutdown", .timeLimit(.minutes(1)))
    func clearsHandler() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let application = terminal.makeApplication()
        var keys: [KeyEvent] = []
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        application.onKeyEvent = { [weak application] key in
            keys.append(key)
            application?.onKeyEvent = nil
            continuation.yield(())
            continuation.finish()
        }
        try terminal.send([0x61, 0x62, 0x0D])
        let task = Task { try await application.run() }
        for await _ in ready {}

        // -- Act --
        try terminal.send([0x03])
        try await task.value

        // -- Assert --
        #expect(keys == [.character("a")])
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Nonterminal input fails without changing descriptor flags")
    func rejectsPipe() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        let session = DefaultTerminalSession(fileDescriptor: .custom(descriptor))
        let application = Application(runLoop: DefaultRunLoop(), terminalSession: session)
        application.onKeyEvent = { _ in Issue.record("Unexpected keyboard event") }
        var receivedError: TerminalError?

        // -- Act --
        do {
            try await application.run()
            Issue.record("A pipe is not a terminal")
        } catch let error as TerminalError {
            receivedError = error
        }

        // -- Assert --
        #expect(receivedError == .readAttributes(errno: ENOTTY))
        #expect(fcntl(descriptor, F_GETFL) == flags)
    }
}
