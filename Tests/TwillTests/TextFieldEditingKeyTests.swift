import Testing

@testable import Twill

@Suite("Single-line editing keys")
@MainActor
struct TextFieldEditingKeyTests {
    @ViewBuilder
    private func field(secure: Bool, text: Binding<String>) -> some View {
        if secure { SecureField("Value", text: text) } else { TextField("Value", text: text) }
    }

    @Test("Home and End move the caret using plain or masked cell geometry", arguments: [false, true])
    func endpoints(secure: Bool) {
        // -- Arrange --
        var text = "A界e\u{301}👩‍💻Z"
        var writes = 0
        let renderer = ViewRenderer.make(
            field(
                secure: secure,
                text: Binding(
                    get: { text },
                    set: {
                        text = $0
                        writes += 1
                    })))
        _ = renderer.render(.now)

        // -- Act --
        let homeHandled = renderer.handle(.home)
        _ = renderer.render(.now)
        let home = renderer.caretPosition
        let endHandled = renderer.handle(.end)
        _ = renderer.render(.now)
        let end = renderer.caretPosition

        // -- Assert --
        #expect(homeHandled && endHandled)
        #expect(home == CellPosition(column: 0, row: 0))
        #expect(end == CellPosition(column: secure ? 5 : 7, row: 0))
        #expect(writes == 0)
    }

    @Test("Forward Delete removes whole graphemes and retains the insertion point", arguments: [false, true])
    func forwardDelete(secure: Bool) throws {
        // -- Arrange --
        var text = "A界e\u{301}👩‍💻Z"
        var outerKeys = 0
        let renderer = ViewRenderer.make(
            field(secure: secure, text: Binding(get: { text }, set: { text = $0 }))
                .onKeyPress { _ in
                    outerKeys += 1
                    return .handled
                })
        _ = renderer.render(.now)
        var frames: [String] = []

        // -- Act --
        _ = renderer.handle(.home)
        for _ in 0..<3 {
            _ = renderer.handle(.delete)
            frames.append(try #require(renderer.render(.now).grid).snapshotText)
        }
        let stationary = renderer.caretPosition
        _ = renderer.handle(.end)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.delete)
        frames.append(try #require(renderer.render(.now).grid).snapshotText)

        // -- Assert --
        #expect(text == "👩‍💻")
        #expect(stationary == CellPosition(column: 0, row: 0))
        #expect(outerKeys == 0)
        #expect(frames == (secure ? ["••••", "•••", "••", "•"] : ["界e\u{301}👩‍💻Z", "e\u{301}👩‍💻Z", "👩‍💻Z", "👩‍💻"]))
    }

    @Test("Endpoint and empty-value no-ops never write the binding", arguments: [false, true])
    func boundaries(secure: Bool) {
        // -- Arrange --
        var writes = 0
        var text = "abc"
        let renderer = ViewRenderer.make(
            field(
                secure: secure,
                text: Binding(
                    get: { text },
                    set: {
                        text = $0
                        writes += 1
                    })))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.end)
        _ = renderer.handle(.delete)
        text = ""
        _ = renderer.render(.now)
        let handled = [.home, .end, .delete, .backspace].map { renderer.handle($0) }
        _ = renderer.render(.now)

        // -- Assert --
        #expect(handled.allSatisfy { $0 })
        #expect(writes == 0)
        #expect(text.isEmpty)
    }

    @Test(
        "Editing keys precede enclosing handlers while submit and unrelated chords still route",
        arguments: [false, true])
    func routing(secure: Bool) {
        // -- Arrange --
        var text = "abc"
        var outerKeys: [KeyEvent] = []
        var submitted: [String] = []
        let renderer = ViewRenderer.make(
            field(secure: secure, text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submitted.append(text) }
                .onKeyPress {
                    outerKeys.append($0)
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        for key: KeyEvent in [.home, .delete, .end, .home.withModifiers(.control), .delete.withModifiers(.control)] {
            _ = renderer.handle(key)
        }
        _ = renderer.handle(.enter)
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(text == "bc")
        #expect(submitted == ["bc"])
        #expect(outerKeys == [.controlS, .escape])
    }

    @Test("External replacements clamp old caret positions before endpoint editing", arguments: [false, true])
    func externalReplacement(secure: Bool) {
        // -- Arrange --
        var text = "abcdef"
        let renderer = ViewRenderer.make(field(secure: secure, text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        text = "界"
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.delete)
        _ = renderer.handle(.home)
        _ = renderer.handle(.delete)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(text.isEmpty)
        #expect(renderer.caretPosition == CellPosition(column: 0, row: 0))
    }
}
