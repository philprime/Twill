import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Menu application input")
@MainActor
struct MenuApplicationTests {
    @Test("Menu actions trap terminal input, dismiss and restore focus and terminal settings", .timeLimit(.minutes(1)))
    func modalInput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var events: [String] = []
        var leakedKeys: [KeyEvent] = []
        let application = Application(
            rootView: HStack {
                Button("Other") { events.append("other") }
                Menu(
                    "Actions",
                    items: [
                        MenuItem("Unavailable", shortcut: MenuShortcut(.d, hint: "d"), isEnabled: false) {
                            events.append("disabled")
                        },
                        MenuItem("Save", shortcut: MenuShortcut(.s, hint: "s")) { events.append("save") },
                    ])
            },
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
                        0x1B, 0x5B, 0x43, 0x0D, 0x78, 0x64, 0x73,
                        0x0D, 0x1B, 0x0D, 0x0D, 0x03,
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
        #expect(events == ["save", "save"])
        #expect(leakedKeys.isEmpty)
        #expect(String(data: data, encoding: .utf8)?.contains("Other") == true)
        let restoredCursor = Data("\n\u{1B}[?25h".utf8)
        #expect(data.suffix(restoredCursor.count) == restoredCursor)
        #expect(try terminal.snapshot() == original)
    }
}
