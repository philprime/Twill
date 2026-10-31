import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Payload dialog terminal interaction")
@MainActor
struct PayloadDialogApplicationTests {
    private struct Payload: Identifiable {
        let id: Int
        let title: String
    }
    private struct Fixture: View {
        @State private var item: Payload?
        let action: @MainActor (String) -> Void
        var body: some View {
            HStack {
                Button("Before") { action("before") }
                Button("Open") {
                    action("open")
                    item = Payload(id: 1, title: "One")
                }
            }.confirmationDialog(
                "Delete?", item: $item, onDismiss: { action("dismiss") },
                actions: { payload in
                    Button("Delete", role: .destructive) { action("delete:\(payload.title)") }
                    Button("Keep", role: .cancel) { action("keep:\(payload.title)") }
                }, message: { Text($0.title) })
        }
    }

    @Test(
        "Cancellation is initially focused and destructive payload actions require navigation", .timeLimit(.minutes(1)))
    func deliberateActivation() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var actions: [String] = []
        var leaked: [KeyEvent] = []
        let application = Application(
            rootView: Fixture(action: { actions.append($0) }), runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { leaked.append($0) }
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\t\rx\r\r\u{1B}[A\r\u{3}".utf8)) } catch {
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
        #expect(actions == ["open", "keep:One", "dismiss", "open", "delete:One", "dismiss"])
        #expect(leaked.isEmpty)
        #expect(try terminal.snapshot() == original)
    }
}
