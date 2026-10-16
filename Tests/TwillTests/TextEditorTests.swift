import Testing

@testable import Twill

@Suite("Multiline text editing")
@MainActor
struct TextEditorTests {
    @Test("Enter inserts a newline without submitting or invoking screen shortcuts")
    func newlineInsertion() throws {
        // -- Arrange --
        var text = "ab"
        var submissions = 0
        var shortcuts = 0
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }))
                .onSubmit { submissions += 1 }
                .onKeyPress { _ in
                    shortcuts += 1
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let newline = renderer.handle(.enter)
        let typed = renderer.handle(.c)
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(newline && typed)
        #expect(text == "ab\nc")
        #expect(grid.size.height == 2)
        #expect(renderer.caretPosition == CellPosition(column: 1, row: 1))
        #expect(submissions == 0)
        #expect(shortcuts == 0)
    }

    @Test("Horizontal movement and deletion cross newline boundaries without splitting graphemes")
    func horizontalEditing() {
        // -- Arrange --
        var text = "a👩‍💻\n界"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.backspace)
        _ = renderer.handle(.backspace)
        _ = renderer.handle(.delete)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.a)

        // -- Assert --
        #expect(text == "aa\n")
    }

    @Test("Scalar input that joins a preceding grapheme leaves the caret before following text")
    func scalarComposition() {
        // -- Arrange --
        var text = "eX"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.character("\u{301}"))
        _ = renderer.handle(.a)

        // -- Assert --
        #expect(text == "e\u{301}aX")
    }

    @Test("Vertical movement preserves a preferred display column across short and wide rows")
    func verticalEditing() throws {
        // -- Arrange --
        var text = "abcde\nx\n界abc"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowUp)
        _ = renderer.render(.now)
        let shortCaret = renderer.caretPosition
        _ = renderer.handle(.arrowUp)
        _ = renderer.render(.now)
        let firstCaret = renderer.caretPosition
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.b)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(shortCaret == CellPosition(column: 1, row: 1))
        #expect(firstCaret == CellPosition(column: 5, row: 0))
        #expect(text == "abcde\nx\n界babc")
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 2))
    }

    @Test("Page keys move the caret by one viewport without leaving the editor")
    func pageNavigation() {
        // -- Arrange --
        var text = "0\n1\n2\n3\n4"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(height: 2))
        _ = renderer.render(.now)

        // -- Act --
        let pagedUp = renderer.handle(.pageUp)
        _ = renderer.handle(.pageDown)
        _ = renderer.handle(.home)
        let secondUp = renderer.handle(.pageUp)
        _ = renderer.handle(.a)

        // -- Assert --
        #expect(pagedUp && secondUp)
        #expect(text == "0\n1\na2\n3\n4")
    }

    @Test("A constrained editor scrolls on both axes to reveal its caret")
    func caretScrolling() throws {
        // -- Arrange --
        var text = "zero\none\ntwo\nabcdef"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 4, height: 2))
        let initial = try #require(renderer.render(.now).grid)
        let initialCaret = renderer.caretPosition

        // -- Act --
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.arrowUp)
        let moved = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.snapshotText.contains("def"))
        #expect(initialCaret == CellPosition(column: 3, row: 1))
        #expect(moved.snapshotText.contains("one"))
        #expect(renderer.caretPosition == CellPosition(column: 0, row: 0))
    }
}
