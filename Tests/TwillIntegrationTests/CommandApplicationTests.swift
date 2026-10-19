import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Command application input")
@MainActor
struct CommandApplicationTests {
    @Test("Commands update availability and restore focus between terminal keys", .timeLimit(.minutes(1)))
    func commandAvailability() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var saved: [String] = []
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: CommandFixture(onSave: { saved.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Save starts disabled. Enter saves after typing, then Ctrl-U
                    // disables the focused Save command and editing must resume.
                    let controlS: UInt8 = 0x13
                    let controlU: UInt8 = 0x15
                    let superS = Array("\u{1B}[115;9u".utf8)
                    try terminal.send([controlS, 0x61, 0x09, 0x0D, controlU, 0x62] + superS + [0x03])
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
        #expect(saved == ["a", "b"])
        #expect(fallback == [.controlS])
        #expect(data.contains(Data("Save".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct CommandFixture: View {
    private enum Action: Hashable { case save, clear }
    @State private var name = ""
    let onSave: @MainActor (String) -> Void

    var body: some View {
        let save = Command(
            Action.save, title: "Save", isEnabled: !name.isEmpty,
            shortcuts: [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)]
        ) { onSave(name) }
        let clear = Command(
            Action.clear, title: "Clear", isEnabled: !name.isEmpty,
            shortcuts: [KeyboardShortcut(.controlU)]
        ) { name = "" }
        return VStack(alignment: .leading) {
            TextField("Name", text: $name)
            HStack {
                Button(save)
                Button(clear)
            }
            KeyHints([save, clear])
        }
    }
}
