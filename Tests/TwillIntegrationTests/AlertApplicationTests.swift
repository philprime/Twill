import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Dialog application input")
@MainActor
struct AlertApplicationTests {
    @Test(
        "Dialog actions trap real input, dismiss and restore focus and terminal state", .timeLimit(.minutes(1)),
        arguments: [false, true])
    func modalInput(confirmation: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var events: [String] = []
        var leakedKeys: [KeyEvent] = []
        let application = Application(
            rootView: DialogInputFixture(confirmation: confirmation, record: { events.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { leakedKeys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send([
                        0x1B, 0x5B, 0x43, 0x0D, 0x78, 0x1B, 0x0D,
                        0x1B, 0x5B, 0x41, 0x0D, 0x0D, 0x03,
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
        #expect(events == ["open", "cancel", "open", "delete", "open"])
        #expect(leakedKeys.isEmpty)
        let restoredCursor = Data("\n\u{1B}[?25h".utf8)
        #expect(data.suffix(restoredCursor.count) == restoredCursor)
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct DialogInputFixture: View {
    @State private var presented = false
    let confirmation: Bool
    let record: @MainActor (String) -> Void

    private var base: some View {
        HStack {
            Button("Other") { record("other") }
            Button("Open") {
                record("open")
                presented = true
            }
        }
        .onKeyPress { key in
            guard key == .x else { return .ignored }
            record("leaked")
            return .handled
        }
    }

    private var actions: some View {
        Group {
            Button("Delete", role: .destructive) { record("delete") }
            Button("Keep", role: .cancel) { record("cancel") }
        }
    }

    @ViewBuilder var body: some View {
        if confirmation {
            base.confirmationDialog("Delete?", isPresented: $presented) { actions }
        } else {
            base.alert("Delete?", isPresented: $presented) { actions }
        }
    }
}
