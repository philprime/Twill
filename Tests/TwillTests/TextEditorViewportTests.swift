import Testing

@testable import Twill

@Suite("Text editor viewport and focus")
@MainActor
struct TextEditorViewportTests {
    @Test("Resize keeps the caret visible and restores content when the viewport grows")
    func resizing() throws {
        // -- Arrange --
        var text = "zero\none\ntwo\nabcdef"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 4))

        // -- Act --
        let small = try #require(renderer.drawFrame(proposal: ProposedCellSize(width: 3, height: 1)))
        let smallCaret = renderer.caretPosition
        let large = try #require(renderer.drawFrame(proposal: ProposedCellSize(width: 8, height: 4)))

        // -- Assert --
        #expect(small.snapshotText == "ef ")
        #expect(smallCaret == CellPosition(column: 2, row: 0))
        #expect(large.snapshotText.contains("zero"))
        #expect(large.snapshotText.contains("abcdef"))
        #expect(renderer.caretPosition == CellPosition(column: 6, row: 3))
    }

    @Test("Empty editors retain an insertion cell and clipped editors hide their caret")
    func emptyAndClipped() throws {
        // -- Arrange --
        var text = ""
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        let empty = try #require(renderer.render(.now).grid)
        let emptyCaret = renderer.caretPosition

        // -- Act --
        _ = renderer.drawFrame(proposal: ProposedCellSize(width: 0, height: 0))
        let hidden = renderer.caretPosition
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.backspace)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(empty.size == CellSize(width: 1, height: 1))
        #expect(emptyCaret == .zero)
        #expect(hidden == nil)
        #expect(restored.size == CellSize(width: 1, height: 1))
        #expect(renderer.caretPosition == .zero)
    }

    @Test("Tab switches panes and preserves the editor caret when focus returns")
    func paneTraversal() throws {
        // -- Arrange --
        var text = "abc\ndef"
        var activations = 0
        let renderer = ViewRenderer.make(
            VStack(spacing: 0) {
                TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 5, height: 2)
                ScrollView { Button("Save") { activations += 1 } }.frame(height: 1)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowUp)
        let switched = renderer.handle(.tab)
        _ = renderer.render(.now)
        let hidden = renderer.caretPosition
        _ = renderer.handle(.enter)
        let returned = renderer.handle(.shiftTab)
        _ = renderer.handle(.a)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(switched && returned)
        #expect(hidden == nil)
        #expect(activations == 1)
        #expect(text == "abca\ndef")
        #expect(renderer.caretPosition == CellPosition(column: 4, row: 0))
    }

    @Test("Escape and modified Enter reach enclosing handlers without inserting text")
    func commandRouting() {
        // -- Arrange --
        var text = "note"
        var commands: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }))
                .onKeyPress {
                    commands.append($0)
                    return .handled
                })
        _ = renderer.render(.now)
        let submit = KeyEvent(.enter, modifiers: [.control])

        // -- Act --
        _ = renderer.handle(submit)
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(commands == [submit, .escape])
        #expect(text == "note")
    }

    @Test("Horizontal clipping omits partial wide graphemes")
    func clippedWideGlyph() throws {
        // -- Arrange --
        var text = "A界B"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 3, height: 1))

        // -- Act --
        let scrolled = try #require(renderer.render(.now).grid)
        let scrolledCaret = renderer.caretPosition
        _ = renderer.handle(.home)
        let beginning = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(scrolled.snapshotText == " B ")
        #expect(scrolledCaret == CellPosition(column: 2, row: 0))
        #expect(beginning.snapshotText == "A界")
        #expect(renderer.caretPosition == .zero)
    }

    @Test("Rendering multiline text sanitizes terminal controls and measures wide caret columns")
    func safeDrawing() throws {
        // -- Arrange --
        var text = "\u{1B}[2J\r\nA界e\u{301}"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(!grid.snapshotText.contains("\u{1B}"))
        #expect(grid.size.height == 2)
        #expect(grid.snapshotText.contains("A界e\u{301}"))
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 1))
    }
}
