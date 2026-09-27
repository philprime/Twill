import Testing

@testable import Twill

@Suite("Buffered cell presentation")
struct InlineFrameEncoderTests {
    @Test("ANSI palette entries use terminal foreground and background codes")
    func ansiPalette() {
        // -- Arrange --
        let palette: [(Color, Int)] = [
            (.black, 30), (.red, 31), (.green, 32), (.yellow, 33),
            (.blue, 34), (.magenta, 35), (.cyan, 36), (.white, 37),
            (.brightBlack, 90), (.brightRed, 91), (.brightGreen, 92), (.brightYellow, 93),
            (.brightBlue, 94), (.brightMagenta, 95), (.brightCyan, 96), (.brightWhite, 97),
        ]

        // -- Act & Assert --
        for (color, code) in palette {
            var frame = CellGrid(size: CellSize(width: 1, height: 1))
            frame.put("X", width: 1, column: 0, row: 0, foreground: color, background: color)
            #expect(
                InlineFrameEncoder.encode(frame, previous: nil)
                    == "\r\u{1B}[2K\u{1B}[\(code)m\u{1B}[\(code + 10)mX\u{1B}[39m\u{1B}[49m")
        }
    }

    @Test("RGB colors still use true-color sequences")
    func rgbColor() {
        // -- Arrange --
        var frame = CellGrid(size: CellSize(width: 1, height: 1))
        frame.put("X", width: 1, column: 0, row: 0, foreground: Color(red: 12, green: 34, blue: 56))

        // -- Act --
        let output = InlineFrameEncoder.encode(frame, previous: nil)

        // -- Assert --
        #expect(output == "\r\u{1B}[2K\u{1B}[38;2;12;34;56mX\u{1B}[39m")
    }

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
