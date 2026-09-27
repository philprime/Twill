import Testing

@testable import Twill

@Suite("Terminal session cursor ownership")
@MainActor
struct TerminalSessionCursorTests {
    @Test("Presentation hides the native cursor once and session restoration shows it once")
    func cursorLifetime() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let session = DefaultTerminalSession(output: output)

        // -- Act --
        try session.beginPresentation()
        try session.beginPresentation()
        session.restore()
        session.restore()

        // -- Assert --
        #expect(output.writes == ["\u{1B}[?25l", "\u{1B}[?25h"])
    }

    @Test("Partial cursor-hide failure still attempts restoration")
    func initialFailure() {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        output.nextFailure = Failure.output
        let session = DefaultTerminalSession(output: output)

        // -- Act --
        #expect(throws: Failure.output) { try session.beginPresentation() }
        session.restore()

        // -- Assert --
        #expect(output.writes == ["\u{1B}[?25h"])
    }

    @Test("Stopping the host does not restore session modes prematurely")
    func hostAndSessionOwnership() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let session = DefaultTerminalSession(output: output)
        let host = ViewHost(
            rootView: Text("Clock"), runLoop: RecordingRunLoop(), output: session.output,
            preparePresentation: { try session.beginPresentation() }
        )
        try host.start()

        // -- Act --
        host.stop()
        let writesBeforeSessionRestore = output.writes
        session.restore()

        // -- Assert --
        #expect(writesBeforeSessionRestore == ["\u{1B}[?25l", "\r\u{1B}[2KClock", "\n"])
        #expect(output.writes.last == "\u{1B}[?25h")
    }

    @Test("A frame failure leaves cursor restoration to session cleanup")
    func frameFailure() {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let session = DefaultTerminalSession(output: output)
        let host = ViewHost(
            rootView: Text("Clock"), runLoop: RecordingRunLoop(), output: session.output,
            preparePresentation: {
                try session.beginPresentation()
                output.nextFailure = Failure.output
            }
        )

        // -- Act --
        #expect(throws: Failure.output) { try host.start() }
        let writesBeforeSessionRestore = output.writes
        session.restore()

        // -- Assert --
        #expect(writesBeforeSessionRestore == ["\u{1B}[?25l"])
        #expect(output.writes == ["\u{1B}[?25l", "\u{1B}[?25h"])
    }

    @Test("An empty host never requests presentation modes")
    func emptyHost() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let session = DefaultTerminalSession(output: output)
        let host = ViewHost(
            rootView: EmptyView(), runLoop: RecordingRunLoop(), output: session.output,
            preparePresentation: { try session.beginPresentation() }
        )

        // -- Act --
        try host.start()
        host.stop()
        session.restore()

        // -- Assert --
        #expect(output.writes.isEmpty)
    }

    private enum Failure: Error { case output }
}
