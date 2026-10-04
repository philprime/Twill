import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Text field application input")
@MainActor
struct TextFieldApplicationTests {
    @Test("Rapid editing updates the binding and restores inherited terminal state", .timeLimit(.minutes(1)))
    func editingRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var committed: [String] = []
        let application = Application(
            rootView: FieldInputFixture(onCommit: {
                committed.append($0)
            }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        application.options.ui.mode = .inline
        var applicationKeys: [KeyEvent] = []
        application.onKeyEvent = { [weak application] key in
            applicationKeys.append(key)
            application?.stop()
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x0D, 0x61, 0x1B, 0x5B, 0x44, 0x62, 0x0D, 0x71, 0x03]) } catch {
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
        #expect(committed == ["ba"])
        #expect(applicationKeys.isEmpty)
        #expect(data.starts(with: Data("\u{1B}[?25l\r\u{1B}[2K\u{1B}[7mSearch\u{1B}[27m".utf8)))
        #expect(data.suffix(Data("\n\u{1B}[?25h".utf8).count) == Data("\n\u{1B}[?25h".utf8))
        #expect(try terminal.snapshot() == original)
    }

    @Test(
        "An editing caret restores the terminal after shutdown or cancellation", .timeLimit(.minutes(1)),
        arguments: [false, true])
    func caretRestoration(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let reader = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        reader.start()
        let runLoop = DefaultRunLoop()
        var text = "界"
        let application = Application(
            rootView: VStack {
                Text("Top")
                TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
            },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        application.options.ui.mode = .inline
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x0D]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })
        // Bound an unexpected failure to show the caret instead of leaving a reader waiting forever.
        runLoop.add(Twill.Timer(interval: .seconds(1)) { application.stop() })
        let task = Task {
            defer { try? pipe.fileHandleForWriting.close() }
            try await application.run()
        }
        defer { task.cancel() }

        // -- Act --
        let (bytes, sawCaret) = try await observeCaret(reader: reader, task: task, terminal: terminal, cancel: cancel)
        try pipe.fileHandleForReading.close()
        let output = try #require(String(bytes: bytes, encoding: .utf8))

        // -- Assert --
        #expect(sawCaret)
        #expect(output.hasSuffix("\u{1B}[?25l\r\u{1B}[1A\u{1B}[1B\r\n\u{1B}[?25h"))
        #expect(try terminal.snapshot() == original)
    }

    private func observeCaret(
        reader: DefaultInputSource, task: Task<Void, Error>, terminal: TestTerminal, cancel: Bool
    ) async throws -> (Data, Bool) {
        let shownCaret = Data("\r\u{1B}[1B\u{1B}[2C\u{1B}[?25h".utf8)
        var bytes = Data()
        var sawCaret = false
        do {
            for try await chunk in reader.events {
                bytes.append(contentsOf: chunk)
                if !sawCaret, bytes.range(of: shownCaret) != nil {
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
private struct FieldInputFixture: View {
    @State private var text = ""
    let onCommit: @MainActor (String) -> Void

    var body: some View {
        TextField("Search", text: $text)
            .onKeyPress { key in
                guard key == .q else { return .ignored }
                onCommit(text)
                return .handled
            }
    }
}
