import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Slider application input")
@MainActor
struct SliderApplicationTests {
    @Test("Real terminal keys adjust the focused slider and restore inherited modes", .timeLimit(.minutes(1)))
    func boundedAdjustment() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var writes: [Double] = []
        var saved: [Double] = []
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: SliderInputFixture(onWrite: { writes.append($0) }, onSave: { saved.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Reach both bounds, move focus to Save, submit, and stop.
                    try terminal.send(Array("\u{1B}[C\u{1B}[C\u{1B}[C\u{1B}[D\u{1B}[H\u{1B}[F\u{1B}[B\r\u{03}".utf8))
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(writes == [0.75, 1, 0.5, 0, 1])
        #expect(saved == [1])
        #expect(fallback.isEmpty)
        #expect(data.contains(Data("Gain".utf8)))
        #expect(data.contains(Data("0.25".utf8)))
        #expect(data.contains(Data("●".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct SliderInputFixture: View {
    @State private var value = 0.25
    let onWrite: @MainActor (Double) -> Void
    let onSave: @MainActor (Double) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Slider(
                "Gain",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        onWrite($0)
                    }),
                step: 0.5)
            Button("Save") { onSave(value) }
        }
    }
}
