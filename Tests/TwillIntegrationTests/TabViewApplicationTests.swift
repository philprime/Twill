import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Tab view application input")
@MainActor
struct TabViewApplicationTests {
    @Test("Terminal shortcuts switch editable tabs and restore their text and focus", .timeLimit(.minutes(1)))
    func editingRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var submissions: [String] = []
        var fallbackKeys: [KeyEvent] = []
        let application = Application(
            rootView: EditingTabs { submissions.append($0) }, runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallbackKeys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Edit both tabs, return to the bar, switch with arrows, reenter, submit, quit.
                    let keys = "\u{1B}[Ba\u{1B}[6;5~b\r\u{1B}[5;5~c\u{1B}[Z\u{1B}[C\u{1B}[D\td\r\u{03}"
                    try terminal.send(Array(keys.utf8))
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
        #expect(submissions == ["Second:b", "First:acd"])
        #expect(fallbackKeys.isEmpty)
        #expect(try #require(String(bytes: data, encoding: .utf8)).contains("[First] Second"))
        #expect(try terminal.snapshot() == original)
    }
}

private struct EditingTabs: View {
    @State private var selection = 0
    let submit: (String) -> Void

    var body: some View {
        TabView(selection: $selection) {
            Tab("First", value: 0) { Editor(name: "First", submit: submit) }
            Tab("Second", value: 1) { Editor(name: "Second", submit: submit) }
        }
    }
}

private struct Editor: View {
    @State private var text = ""
    let name: String
    let submit: (String) -> Void

    var body: some View {
        TextField(name, text: $text).onSubmit { submit("\(name):\(text)") }
    }
}
