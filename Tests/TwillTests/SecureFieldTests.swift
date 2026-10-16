import Testing

@testable import Twill

@Suite("Secure field input")
@MainActor
struct SecureFieldTests {
    @Test("Rendered frames mask each character, including wide and combining characters")
    func masksValue() throws {
        // -- Arrange --
        var text = "A界e\u{301}🔐\n"
        let renderer = ViewRenderer.make(
            SecureField("Password", text: Binding(get: { text }, set: { text = $0 })))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "•••••")
        #expect(text == "A界e\u{301}🔐\n")
    }

    @Test("An empty field shows its prompt and returns to it after deletion")
    func emptyPrompt() throws {
        // -- Arrange --
        var text = ""
        let renderer = ViewRenderer.make(
            SecureField("Password", text: Binding(get: { text }, set: { text = $0 })))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.a)
        let entered = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.backspace)
        let cleared = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.snapshotText == "Password")
        #expect(entered.snapshotText == "•")
        #expect(cleared.snapshotText == "Password")
        #expect(text.isEmpty)
    }

    @Test("Editing and submission preserve the bound value without revealing it")
    func editsAndSubmits() throws {
        // -- Arrange --
        var text = "ab"
        var submissions: [String] = []
        var shortcuts = 0
        let renderer = ViewRenderer.make(
            SecureField("Password", text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submissions.append(text) }
                .onKeyPress { _ in
                    shortcuts += 1
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.backspace)
        _ = renderer.render(.now)
        _ = renderer.handle(.questionMark)
        _ = renderer.render(.now)
        let submitted = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowRight)
        _ = renderer.render(.now)
        _ = renderer.handle(.a)
        let frame = try #require(renderer.render(.now).grid)
        let escaped = renderer.handle(.escape)

        // -- Assert --
        #expect(submitted)
        #expect(submissions == ["?b"])
        #expect(text == "?ba")
        #expect(frame.snapshotText == "•••")
        #expect(escaped)
        #expect(shortcuts == 1)
    }

    @Test("The host positions the caret using masked cells and never writes the value")
    func maskedCaretAndOutput() throws {
        // -- Arrange --
        var text = "界🔐"
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let host = ViewHost(
            rootView: SecureField("Password", text: Binding(get: { text }, set: { text = $0 })),
            runLoop: runLoop, output: output)
        try host.start()
        defer { host.stop() }
        let source = try #require(runLoop.sources.first)
        source.action()
        let initial = try #require(output.writes.last)

        // -- Act --
        _ = host.handle(.arrowLeft)
        source.action()
        let moved = try #require(output.writes.last)
        _ = host.handle(.a)
        source.action()
        let inserted = try #require(output.writes.last)

        // -- Assert --
        #expect(initial.contains("••"))
        #expect(initial.contains("\r\u{1B}[2C\u{1B}[?25h"))
        #expect(moved.contains("\r\u{1B}[1C\u{1B}[?25h"))
        #expect(inserted.contains("•"))
        #expect(text == "界a🔐")
        #expect(output.writes.allSatisfy { !$0.contains("界") && !$0.contains("🔐") && !$0.contains("a") })
    }
}
