import Testing

@testable import Twill

@Suite("Text editor soft wrapping")
@MainActor
struct TextEditorWrappingTests {
    @Test("Character wrapping reserves an insertion cell without changing the binding")
    func characterRows() throws {
        // -- Arrange --
        var text = "abcdef"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .characterWrapping)
                .frame(width: 4, height: 2))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "abc \ndef ")
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 1))
        #expect(text == "abcdef")
    }

    @Test("Word wrapping preserves separating spaces and logical editing offsets")
    func wordRows() throws {
        // -- Arrange --
        var text = "one two"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .wordWrapping)
                .frame(width: 5, height: 2))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowRight.withModifiers(.control))
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.delete)
        let edited = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.snapshotText == "one  \ntwo  ")
        #expect(text == "one wo")
        #expect(edited.snapshotText == "one  \nwo   ")
        #expect(renderer.caretPosition == CellPosition(column: 0, row: 1))
    }

    @Test("Vertical preferred columns retain visual end-of-row affinity")
    func verticalNavigation() {
        // -- Arrange --
        var text = "abcdef\nxy\n123456"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .characterWrapping)
                .frame(width: 4, height: 5))
        _ = renderer.render(.now)
        var positions: [CellPosition?] = []

        // -- Act --
        for key: KeyEvent in [.arrowUp, .arrowUp, .arrowUp, .arrowDown, .arrowDown] {
            _ = renderer.handle(key)
            _ = renderer.render(.now)
            positions.append(renderer.caretPosition)
        }

        // -- Assert --
        #expect(
            positions == [
                CellPosition(column: 3, row: 3), CellPosition(column: 2, row: 2),
                CellPosition(column: 3, row: 1), CellPosition(column: 2, row: 2), CellPosition(column: 3, row: 3),
            ])
        #expect(text == "abcdef\nxy\n123456")
    }

    @Test("Read-only wide and combining graphemes retain cell-safe wrapped navigation")
    func unicodeReadOnly() throws {
        // -- Arrange --
        var text = "A界e\u{301}👩‍💻Z"
        let original = text
        let renderer = ViewRenderer.make(
            TextEditor(
                text: Binding(get: { text }, set: { text = $0 }), editingMode: .readOnly,
                lineBreakMode: .characterWrapping
            ).frame(width: 5, height: 2))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.delete)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(initial.snapshotText == "A界e\u{301} \n👩‍💻Z  ")
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 0))
        #expect(text == original)
    }

    @Test("Resize reflows cached descriptions without reevaluating bodies")
    func resizing() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(CountedEditor(evaluated: { evaluations += 1 }))
        let wide = try #require(renderer.render(.now, proposal: .init(width: 7, height: 2)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 4, height: 2)))
        let narrowCaret = renderer.caretPosition
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 7, height: 2)))

        // -- Assert --
        #expect(wide.snapshotText == "abcdef \n       ")
        #expect(narrow.snapshotText == "abc \ndef ")
        #expect(narrowCaret == CellPosition(column: 3, row: 1))
        #expect(restored == wide)
        #expect(evaluations == 1)
    }

    private struct CountedEditor: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return TextEditor(text: .constant("abcdef"), lineBreakMode: .characterWrapping)
        }
    }

    @Test("Switching wrapping modes retains logical caret and restores horizontal scrolling")
    func modeChanges() throws {
        // -- Arrange --
        var text = "abcdef"
        func editor(_ mode: Text.LineBreakMode) -> some View {
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: mode)
                .frame(width: 4, height: 2)
        }
        let renderer = ViewRenderer.make(editor(.clipping))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(editor(.characterWrapping), at: .now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        let wrapped = renderer.caretPosition
        renderer.update(editor(.clipping), at: .now)
        let unwrapped = try #require(renderer.render(.now).grid)
        renderer.update(editor(.wordWrapping), at: .now)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(wrapped == CellPosition(column: 2, row: 1))
        #expect(unwrapped.snapshotText == "cdef\n    ")
        #expect(renderer.caretPosition == wrapped)
        #expect(text == "abcdef")
    }

    @Test("Page movement follows visual rows and insertion at a shared boundary uses the logical offset")
    func pagesAndBoundaryInsertion() throws {
        // -- Arrange --
        var text = "abcdefghijkl"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .characterWrapping)
                .frame(width: 4, height: 2))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.pageUp)
        let page = try #require(renderer.render(.now).grid)
        let caret = renderer.caretPosition
        _ = renderer.handle(.x)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(page.snapshotText == "def \nghi ")
        #expect(caret == CellPosition(column: 3, row: 0))
        #expect(text == "abcdefxghijkl")
    }

    @Test("External replacements preserve a valid logical caret across new visual rows")
    func externalReplacement() throws {
        // -- Arrange --
        var text = "abcdef"
        func editor() -> some View {
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .characterWrapping)
                .frame(width: 4, height: 2)
        }
        let renderer = ViewRenderer.make(editor())
        _ = renderer.render(.now)
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowRight)

        // -- Act --
        text = "界ab"
        renderer.update(editor(), at: .now)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "界a \nb   ")
        #expect(renderer.caretPosition == CellPosition(column: 2, row: 0))
    }

    @Test("Word and character layouts retain every whitespace and empty-line insertion position")
    func sourceMapping() {
        // -- Arrange --
        let text = "  e\u{301} 界  \n\n b "
        let content = TextEditorContent(text)

        // -- Act --
        let layouts: [TextEditorLayout] = [Text.LineBreakMode.wordWrapping, .characterWrapping].flatMap { mode in
            (3...8).map { TextEditorLayout(content: content, width: $0, mode: mode) }
        }

        // -- Assert --
        for layout in layouts {
            #expect(layout.lines.map(\.text).joined() == text.filter { !$0.isNewline })
            for offset in 0...text.count {
                let position = layout.position(at: offset, upstream: false)
                #expect(layout.destination(row: position.row, column: position.column).offset == offset)
            }
        }
    }

    @Test("Resize preserves the logical insertion point of an upstream visual caret")
    func upstreamResize() throws {
        // -- Arrange --
        var text = "abcdef"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: .characterWrapping))
        _ = renderer.render(.now, proposal: .init(width: 4, height: 3))
        _ = renderer.handle(.arrowUp)
        _ = renderer.render(.now, proposal: .init(width: 4, height: 3))

        // -- Act --
        _ = renderer.drawFrame(proposal: .init(width: 5, height: 3))
        let reflowed = renderer.caretPosition
        _ = renderer.handle(.x)
        _ = renderer.render(.now, proposal: .init(width: 5, height: 3))

        // -- Assert --
        #expect(reflowed == CellPosition(column: 3, row: 0))
        #expect(text == "abcxdef")
    }

    @Test("Tiny viewports make progress and zero dimensions hide the caret")
    func tinyViewport() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(TextEditor(text: .constant("界A"), lineBreakMode: .wordWrapping))

        // -- Act --
        let tiny = try #require(renderer.render(.now, proposal: .init(width: 1, height: 2)).grid)
        _ = renderer.drawFrame(proposal: .init(width: 0, height: 0))

        // -- Assert --
        #expect(tiny.snapshotText == " \n ")
        #expect(renderer.caretPosition == nil)
    }
}
