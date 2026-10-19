import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Word editing terminal input")
@MainActor
struct WordEditingApplicationTests {
    enum Kind: CaseIterable, Sendable { case field, secure, editor }

    @ViewBuilder
    private func input(_ kind: Kind, text: Binding<String>, mode: TextEditingMode) -> some View {
        switch kind {
        case .field: TextField("Value", text: text, editingMode: mode)
        case .secure: SecureField("Password", text: text, editingMode: mode)
        case .editor: TextEditor(text: text, editingMode: mode)
        }
    }

    @Test(
        "Modified terminal reports obey editing mode, masking, submit and cleanup contracts",
        .timeLimit(.minutes(1)), arguments: Kind.allCases, [TextEditingMode.editable, .readOnly])
    func terminalEditing(kind: Kind, mode: TextEditingMode) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        let initial = "one, two_界 👩‍💻!"
        var text = initial
        var submitted: [String] = []
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: input(kind, text: Binding(get: { text }, set: { text = $0 }), mode: mode)
                .onSubmit { submitted.append(text) },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Xterm modified arrows/Delete, Alt-Backspace and CSI-u Ctrl-Backspace.
                    let words = "\u{1B}[1;5D\u{1B}[1;3D\u{1B}[1;5C\u{1B}\u{7F}\u{1B}[3;5~\u{1B}[127;5u\u{1B}[127;5u"
                    try terminal.send(Array((words + "x\r\u{13}\u{3}").utf8))
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
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        let expected = mode == .readOnly ? initial : (kind == .editor ? "x\n" : "x")
        #expect(text == expected)
        #expect(submitted == (kind == .editor ? [] : [expected]))
        #expect(fallback == [.controlS])
        if kind == .secure {
            #expect(output.contains(String(repeating: "•", count: initial.count)))
            #expect(!output.contains("two_") && !output.contains("界") && !output.contains("👩‍💻"))
        }
        #expect(try terminal.snapshot() == original)
    }
}
