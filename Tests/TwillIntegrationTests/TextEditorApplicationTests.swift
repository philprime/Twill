import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Text editor application input")
@MainActor
struct TextEditorApplicationTests {
    @Test(
        "Real terminal input edits multiple lines and switches to save without submitting newlines",
        .timeLimit(.minutes(1)))
    func multilineRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var saved: [String] = []
        var submissions = 0
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: EditorInputFixture(onSave: { saved.append($0) })
                .onSubmit { submissions += 1 },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send(
                        Array("ab\r界".utf8) + [
                            0x1B, 0x5B, 0x41, 0x1B, 0x5B, 0x44, 0x78, 0x09, 0x0D, 0x03,
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
        #expect(saved == ["axb\n界"])
        #expect(submissions == 0)
        #expect(fallback.isEmpty)
        #expect(data.contains(Data("\u{1B}[?25h".utf8)))
        #expect(try terminal.snapshot() == original)
    }

    @Test("A multiline caret is hidden before terminal restoration", .timeLimit(.minutes(1)), arguments: [false, true])
    func caretRestoration(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        reader.start()
        let runLoop = DefaultRunLoop()
        var text = "top\n界"
        let application = Application(
            rootView: TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 6, height: 2),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        runLoop.add(Twill.Timer(interval: .seconds(1)) { application.stop() })
        let task = Task {
            defer { try? pipe.fileHandleForWriting.close() }
            try await application.run()
        }
        defer { task.cancel() }

        // -- Act --
        let (data, sawCaret) = try await observeCaret(reader: reader, task: task, terminal: terminal, cancel: cancel)
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        #expect(sawCaret)
        #expect(output.hasSuffix("\u{1B}[?25l\r\u{1B}[1A\u{1B}[1B\r\n\u{1B}[?25h"))
        #expect(try terminal.snapshot() == original)
    }

    private func observeCaret(
        reader: DefaultInputSource, task: Task<Void, Error>, terminal: TestTerminal, cancel: Bool
    ) async throws -> (Data, Bool) {
        let caret = Data("\r\u{1B}[1B\u{1B}[2C\u{1B}[?25h".utf8)
        var bytes = Data()
        var sawCaret = false
        do {
            for try await chunk in reader.events {
                bytes.append(contentsOf: chunk)
                if !sawCaret, bytes.range(of: caret) != nil {
                    sawCaret = true
                    if cancel {
                        task.cancel()
                    } else {
                        try terminal.send([0x03])
                    }
                }
            }
            try await task.value
        } catch {
            task.cancel()
            _ = await task.result
            await reader.stop()
            throw error
        }
        await reader.stop()
        return (bytes, sawCaret)
    }
}

@MainActor
private struct EditorInputFixture: View {
    @State private var text = ""
    let onSave: @MainActor (String) -> Void

    var body: some View {
        VStack {
            TextEditor(text: $text).frame(width: 6, height: 2)
            ScrollView { Button("Save") { onSave(text) } }.frame(height: 1)
        }
    }
}
