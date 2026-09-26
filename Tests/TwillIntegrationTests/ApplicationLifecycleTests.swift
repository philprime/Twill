import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Application lifecycle")
@MainActor
struct ApplicationLifecycleTests {
    @Test("Ctrl-C works without an application key handler", .timeLimit(.minutes(1)))
    func noKeyHandler() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x03]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        runLoop.add(
            Twill.Timer(interval: .seconds(1)) {
                Issue.record("Ctrl-C did not stop the application")
                application.stop()
            })

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(application.onKeyEvent == nil)
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("A key handler can be installed after run has started", .timeLimit(.minutes(1)))
    func installsHandlerWhileRunning() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                application.onKeyEvent = { keys.append($0) }
                do { try terminal.send([0x61, 0x03]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.character("a")])
    }

    @Test("A timer can stop the application while keyboard input is idle", .timeLimit(.minutes(1)))
    func timerStopsApplication() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var ticks = 0
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1), repeats: true) {
                ticks += 1
                if ticks == 3 { application.stop() }
            })

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(ticks == 3)
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }

    @Test("Reader setup failure restores inherited terminal modes", .timeLimit(.minutes(1)))
    func readerFailureRestoresTerminal() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(-1)), runLoop: runLoop
        )
        let application = Application(
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(fileDescriptor: .custom(terminal.fileDescriptor)),
            keyboardEventSource: keyboard
        )
        var receivedError: TerminalError?

        // -- Act --
        do { try await application.run() } catch { receivedError = error as? TerminalError }

        // -- Assert --
        #expect(receivedError == .configureInput(errno: EBADF))
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }
}
