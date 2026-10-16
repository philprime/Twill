import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Stepper application input")
@MainActor
struct StepperApplicationTests {
    @Test("Real terminal arrows adjust only the focused stepper and restore terminal modes", .timeLimit(.minutes(1)))
    func boundedAdjustment() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var writes: [Int] = []
        var saved: [Int] = []
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: StepperInputFixture(onWrite: { writes.append($0) }, onSave: { saved.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Increase to the bound, try again, decrease, move focus, save, and stop.
                    try terminal.send([
                        0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x44,
                        0x1B, 0x5B, 0x42, 0x0D, 0x03,
                    ])
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
        #expect(writes == [2, 1])
        #expect(saved == [1])
        #expect(fallback.isEmpty)
        #expect(data.contains(Data("Count: 1".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct StepperInputFixture: View {
    @State private var count = 1
    let onWrite: @MainActor (Int) -> Void
    let onSave: @MainActor (Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Stepper(
                "Count",
                value: Binding(
                    get: { count },
                    set: {
                        count = $0
                        onWrite($0)
                    }),
                in: 0...2)
            Button("Save") { onSave(count) }
        }
    }
}
