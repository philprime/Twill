import Testing

@testable import Twill

@Suite("Text field editing")
@MainActor
struct TextFieldTests {
    @Test("A focused field accepts text immediately and consumes caret keys before shortcuts")
    func immediateEditing() throws {
        // -- Arrange --
        var text = "ab"
        var shortcuts = 0
        let renderer = ViewRenderer.make(
            TextField("Search", text: Binding(get: { text }, set: { text = $0 }))
                .onKeyPress { _ in
                    shortcuts += 1
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let inserted = renderer.handle(.questionMark)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.backspace)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(inserted)
        #expect(text == "a?")
        #expect(frame.snapshotText == "a?")
        #expect(shortcuts == 0)
    }

    @Test("Submit observes the current value and leaves the field editable")
    func submitsWithoutMovingFocus() {
        // -- Arrange --
        var text = ""
        var submissions: [String] = []
        let renderer = ViewRenderer.make(
            TextField("Search", text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submissions.append(text) })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.a)
        _ = renderer.render(.now)
        let submitted = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.b)

        // -- Assert --
        #expect(submitted)
        #expect(submissions == ["a"])
        #expect(text == "ab")
    }

    @Test("Escape propagates to the enclosing handler without reverting text")
    func escapePropagation() {
        // -- Arrange --
        var text = "ab"
        var escapes = 0
        let renderer = ViewRenderer.make(
            TextField("Search", text: Binding(get: { text }, set: { text = $0 }))
                .onKeyPress { key in
                    guard key == .escape else { return .ignored }
                    escapes += 1
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.escape)

        // -- Assert --
        #expect(handled)
        #expect(escapes == 1)
        #expect(text == "ab")
    }
}
