import Testing

@testable import Twill

@Suite("Buffered cell presentation")
struct InlineFrameEncoderTests {
    @Test("A multi-row frame presents both rows without trapping")
    func initialRows() {
        // -- Arrange --
        var frame = CellGrid(size: CellSize(width: 1, height: 2))
        frame.put("A", width: 1, column: 0, row: 0)
        frame.put("B", width: 1, column: 0, row: 1)

        // -- Act --
        let output = InlineFrameEncoder.encode(frame, previous: nil)

        // -- Assert --
        #expect(output.contains("A"))
        #expect(output.contains("B"))
    }

    @Test("Only changed cell runs are encoded")
    func changedRuns() {
        // -- Arrange --
        let previous = grid("F1 S1")
        let next = grid("F2 S2")

        // -- Act --
        let output = InlineFrameEncoder.encode(next, previous: previous)

        // -- Assert --
        #expect(output == "\r\u{1B}[1C2\r\u{1B}[4C2")
        #expect(InlineFrameEncoder.encode(next, previous: next).isEmpty)
    }

    @Test("Shorter frames erase stale trailing cells")
    func shrinkingFrame() {
        // -- Arrange --
        let previous = grid("Hello")

        // -- Act --
        let output = InlineFrameEncoder.encode(grid("Hi"), previous: previous)

        // -- Assert --
        #expect(output == "\r\u{1B}[1Ci   ")
    }

    @Test("Replacing wide glyphs emits complete glyphs and clears their old footprint")
    func wideReplacement() {
        // -- Arrange --
        let previous = grid("界X")

        // -- Act --
        let narrow = InlineFrameEncoder.encode(grid("ABX"), previous: previous)
        let wide = InlineFrameEncoder.encode(grid("界X"), previous: grid("ABX"))

        // -- Assert --
        #expect(narrow == "\rAB")
        #expect(wide == "\r界")
    }

    @Test("An invalidated baseline redraws the line and empty content clears it")
    func invalidation() {
        // -- Arrange --
        let frame = grid("Clock")

        // -- Act --
        let output = InlineFrameEncoder.encode(frame, previous: frame, invalidate: true)
        let cleared = InlineFrameEncoder.encode(nil, previous: frame)

        // -- Assert --
        #expect(output == "\r\u{1B}[2KClock")
        #expect(cleared == "\r\u{1B}[2K")
        #expect(InlineFrameEncoder.encode(nil, previous: nil).isEmpty)
    }

    private func grid(_ text: String) -> CellGrid {
        let drawing = TextDrawing(text)
        var context = DrawingContext(size: drawing.sizeThatFits(.unspecified))
        drawing.draw(in: &context)
        return context.grid
    }
}
