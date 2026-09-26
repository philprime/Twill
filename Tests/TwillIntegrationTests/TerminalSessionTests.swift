import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Terminal input configuration")
@MainActor
struct TerminalSessionTests {
    @Test("Raw input disables inherited transformations and software flow control")
    func rawInputConfiguration() throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let flowControl = tcflag_t(IXON | IXOFF | IXANY)
        let transformations = tcflag_t(ICRNL | INLCR | IGNCR | ISTRIP | BRKINT | PARMRK)
        let localProcessing = tcflag_t(ICANON | ECHO | ECHONL | ISIG | IEXTEN)
        try terminal.configure { mode in
            mode.c_iflag |= flowControl | transformations
            mode.c_lflag |= localProcessing
            withUnsafeMutableBytes(of: &mode.c_cc) { characters in
                characters[Int(VMIN)] = 0
                characters[Int(VTIME)] = 5
            }
        }
        let original = try terminal.snapshot()
        let session = DefaultTerminalSession(fileDescriptor: .custom(terminal.fileDescriptor))
        defer { session.restore() }

        // -- Act --
        try session.start()
        let active = try terminal.snapshot()
        session.restore()
        let restored = try terminal.snapshot()

        // -- Assert --
        #expect(active.input & flowControl == 0)
        #expect(active.input & transformations == 0)
        #expect(active.local & localProcessing == 0)
        #expect(active.characters[Int(VMIN)] == 1)
        #expect(active.characters[Int(VTIME)] == 0)
        #expect(active.output == original.output)
        #expect(restored == original)
    }

    @Test("Ctrl-S and Ctrl-Q remain application keys with inherited flow control", .timeLimit(.minutes(1)))
    func flowControlKeys() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let runLoop = DefaultRunLoop()
        let application = terminal.makeApplication(runLoop: runLoop)
        var keys: [KeyEvent] = []
        application.onKeyEvent = { keys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x13, 0x11, 0x03]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()

        // -- Assert --
        #expect(keys == [.control(0x13), .control(0x11)])
        let restored = try terminal.snapshot()
        #expect(restored == original)
    }
}
