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
                    try terminal.send([0x61, 0x1B, 0x5B, 0x41, 0xC3, 0xA9, 0x71, 0x62])
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { [weak application] key in
            MainActor.assertIsolated()
            do { running = try terminal.snapshot() } catch { Issue.record(error) }
            keys.append(key)
            if key == .q { application?.stop() }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        let active = try #require(running)
        #expect(active.local & tcflag_t(ICANON | ECHO | ISIG) == 0)
        #expect(active.descriptorFlags & O_NONBLOCK != 0)
        #expect(keys == [.a, .arrowUp, .character("é"), .q])
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
        #expect(keys == [.a])
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Ctrl-C and Ctrl-D exit by default", .timeLimit(.minutes(1)), arguments: [UInt8(0x03), 0x04])
    func defaultExitKey(byte: UInt8) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([byte, 0x71]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { key in
            keys.append(key)
            if key == .q { application.stop() }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys.isEmpty)
        #expect(try terminal.snapshot() == original)
    }

    @Test("Exit keys can be independently disabled", .timeLimit(.minutes(1)), arguments: [UInt8(0x03), 0x04])
    func disabledExitKey(byte: UInt8) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        if byte == 0x03 {
            application.options.exitOnControlC = false
        } else {
            application.options.exitOnControlD = false
        }
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([byte, 0x71]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { key in
            keys.append(key)
            if key == .q { application.stop() }
        }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.control(byte), .q])
    }

    @Test("Disabling one exit key leaves the other active", .timeLimit(.minutes(1)), arguments: [UInt8(0x03), 0x04])
    func independentExitKeys(disabledByte: UInt8) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        application.options.exitOnControlC = disabledByte != 0x03
        application.options.exitOnControlD = disabledByte != 0x04
        let enabledByte: UInt8 = disabledByte == 0x03 ? 0x04 : 0x03
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([disabledByte, enabledByte, 0x71]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        application.onKeyEvent = { keys.append($0) }

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.control(disabledByte)])
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
        #expect(firstHandler == [.a])
        #expect(secondHandler == [.b])
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
        #expect(keys == [.a])
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
        let application = Application(rootView: EmptyView(), runLoop: DefaultRunLoop(), terminalSession: session)
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
