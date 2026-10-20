import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Picker presentation terminal interaction")
@MainActor
struct PickerPresentationApplicationTests {
    @Test(
        "Presentation selection keys and Tab retain control boundaries and terminal restoration",
        .timeLimit(.minutes(1)), arguments: [PickerPresentation.inline, .compact, .vertical])
    func presentations(mode: PickerPresentation) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var selection = "A"
        var completed = 0
        let application = Application(
            rootView: VStack {
                Picker(
                    "Mode", selection: Binding(get: { selection }, set: { selection = $0 }),
                    options: ["A", "B", "C"], presentation: mode)
                Button("Done") { completed += 1 }
            },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                let arrow = mode == .vertical ? "\u{1B}[B" : "\u{1B}[C"
                do { try terminal.send(Array((arrow + "\t\r\u{3}").utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(selection == "B")
        #expect(completed == 1)
        #expect(try terminal.snapshot() == original)
    }
}
