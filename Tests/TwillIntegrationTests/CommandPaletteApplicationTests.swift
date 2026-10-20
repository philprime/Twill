import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Command palette terminal interaction")
@MainActor
struct CommandPaletteApplicationTests {
    private struct Fixture: View {
        @State private var presented = false
        let action: @MainActor (String) -> Void
        var body: some View {
            let save = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)]) { action("save") }
            return HStack {
                Button("Before") { action("before") }
                Button("Open") {
                    action("open")
                    presented = true
                }
                Button(save)
            }.commandPalette(isPresented: $presented, commands: [save])
        }
    }

    @Test(
        "Search isolates shortcut chords, activates filtered commands and restores the opener", .timeLimit(.minutes(1)))
    func searchScope() async throws {
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
                do { try terminal.send(Array("\t\r\u{13}s\r\rz\r\u{1B}\u{3}".utf8)) } catch {
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
        #expect(actions == ["open", "save", "open"])
        #expect(leaked.isEmpty)
        #expect(try terminal.snapshot() == original)
    }
}
