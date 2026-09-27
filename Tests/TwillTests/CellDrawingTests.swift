import Testing

@testable import Twill

@Suite("Cell drawing")
struct CellDrawingTests {
    @Test("Text measures terminal columns rather than characters")
    func terminalColumns() {
        // -- Arrange --
        let text = TextDrawing("A界e\u{301}👩‍💻")

        // -- Act --
        let size = text.sizeThatFits(.unspecified)
        var context = DrawingContext(size: size)
        text.draw(in: &context)

        // -- Assert --
        #expect(size == CellSize(width: 6, height: 1))
        #expect(context.grid[1, 0] == .glyph("界", width: 2))
        #expect(context.grid[2, 0] == .continuation)
        #expect(context.grid[3, 0] == .glyph("e\u{301}", width: 1))
        #expect(context.grid[5, 0] == .continuation)
    }

    @Test("Emoji selectors only widen emoji-capable graphemes")
    func emojiSelectors() {
        // -- Arrange --
        let plainWithSelector: Character = "A\u{FE0F}"
        let emoji: Character = "©\u{FE0F}"
        let text: Character = "©\u{FE0E}"

        // -- Act --
        let widths = [plainWithSelector, emoji, text].map { TerminalCharacterWidth.columns(for: $0) }

        // -- Assert --
        #expect(widths == [1, 2, 1])
    }

    @Test("Child drawing uses local coordinates and intersected clipping")
    func localCoordinates() {
        // -- Arrange --
        var context = DrawingContext(size: CellSize(width: 6, height: 2))

        // -- Act --
        context.withRegion(CellRect(column: 2, row: 1, width: 2, height: 1)) { child in
            TextDrawing("ABC").draw(in: &child)
        }
        TextDrawing("X").draw(in: &context)

        // -- Assert --
        #expect(context.grid[0, 0] == .glyph("X", width: 1))
        #expect(context.grid[2, 1] == .glyph("A", width: 1))
        #expect(context.grid[3, 1] == .glyph("B", width: 1))
        #expect(context.grid[4, 1] == .blank)
    }

    @Test("Clipping never draws half a wide character")
    func wideClipping() {
        // -- Arrange --
        var context = DrawingContext(size: CellSize(width: 2, height: 1))

        // -- Act --
        TextDrawing("A界").draw(in: &context)

        // -- Assert --
        #expect(context.grid[0, 0] == .glyph("A", width: 1))
        #expect(context.grid[1, 0] == .blank)
    }

    @Test("Overwriting a continuation clears the entire old glyph")
    func overwriteWideGlyph() {
        // -- Arrange --
        var context = DrawingContext(size: CellSize(width: 3, height: 1))
        TextDrawing("界").draw(in: &context)

        // -- Act --
        context.withRegion(CellRect(column: 1, row: 0, width: 2, height: 1)) { child in
            TextDrawing("X").draw(in: &child)
        }

        // -- Assert --
        #expect(context.grid[0, 0] == .blank)
        #expect(context.grid[1, 0] == .glyph("X", width: 1))
    }

    @Test("Standalone zero-width characters cannot shift or modify adjacent cells")
    func standaloneMarks() {
        // -- Arrange --
        let text = TextDrawing("\u{301}\u{200B}A")
        var context = DrawingContext(size: text.sizeThatFits(.unspecified))

        // -- Act --
        text.draw(in: &context)

        // -- Assert --
        #expect(context.grid.size == CellSize(width: 3, height: 1))
        #expect(context.grid[0, 0] == .glyph("◌\u{301}", width: 1))
        #expect(context.grid[1, 0] == .blank)
        #expect(context.grid[2, 0] == .glyph("A", width: 1))
    }

    @Test("Text sanitizes control characters before measurement and drawing")
    func sanitization() {
        // -- Arrange --
        let text = TextDrawing("A\u{1B}\nB")
        var context = DrawingContext(size: text.sizeThatFits(.unspecified))

        // -- Act --
        text.draw(in: &context)

        // -- Assert --
        #expect(context.grid.size == CellSize(width: 4, height: 1))
        #expect(context.grid[1, 0] == .blank)
        #expect(context.grid[2, 0] == .blank)
    }
}
