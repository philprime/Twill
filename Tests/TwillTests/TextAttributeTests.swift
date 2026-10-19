import Testing

@testable import Twill

@Suite("Terminal text attributes")
@MainActor
struct TextAttributeTests {
    @Test("Inherited flags compose with local overrides, wide glyphs, colors and focus")
    func inheritance() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("界").bold(false).italic()
                Text("C").textAttributes([])
                Text("D").underline(false)
            }.textAttributes([.bold, .dim, .underline]).foregroundStyle(Color.red).focusable())

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "A界CD")
        #expect(frame.attributes(column: 0, row: 0) == [.bold, .dim, .underline])
        #expect(frame.attributes(column: 1, row: 0) == [.dim, .italic, .underline])
        #expect(frame.attributes(column: 2, row: 0) == [.dim, .italic, .underline])
        #expect(frame.attributes(column: 3, row: 0).isEmpty)
        #expect(frame.attributes(column: 4, row: 0) == [.bold, .dim])
        #expect(frame.isFocused(column: 2, row: 0))
        #expect(frame.foreground(column: 3, row: 0) == .red)
    }

    @Test("Attribute modifiers preserve transparent collection composition")
    func transparentComposition() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                ForEach(["A", "B"], id: \.self) { Text($0) }.bold()
                Text("C")
            })

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "A\nB\nC")
        #expect(frame.attributes(column: 0, row: 0) == [.bold])
        #expect(frame.attributes(column: 0, row: 1) == [.bold])
        #expect(frame.attributes(column: 0, row: 2).isEmpty)
    }

    @Test("Canvas cells inherit or replace attributes including explicit empty sets")
    func canvasOverrides() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Canvas { context, _ in
                context.draw("A", column: 0, row: 0)
                context.draw("B", column: 1, row: 0, attributes: [])
                var buffer = Canvas.Buffer(size: Canvas.Size(width: 2, height: 1))
                buffer[0, 0] = Canvas.Cell("C", attributes: [.dim])
                buffer[1, 0] = Canvas.Cell("D")
                context.render(buffer, column: 2)
            }.frame(width: 4, height: 1).bold())

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.attributes(column: 0, row: 0) == [.bold])
        #expect(frame.attributes(column: 1, row: 0).isEmpty)
        #expect(frame.attributes(column: 2, row: 0) == [.dim])
        #expect(frame.attributes(column: 3, row: 0) == [.bold])
    }

    @Test("Overwriting a wide glyph clears attributes from both old cells")
    func overwrite() {
        // -- Arrange --
        var grid = CellGrid(size: CellSize(width: 3, height: 1))
        grid.put("界", width: 2, column: 0, row: 0, attributes: [.bold, .underline])

        // -- Act --
        grid.put("X", width: 1, column: 1, row: 0, attributes: [.italic])

        // -- Assert --
        #expect(grid[0, 0] == .blank)
        #expect(grid.attributes(column: 0, row: 0).isEmpty)
        #expect(grid.attributes(column: 1, row: 0) == [.italic])
        #expect(grid.attributes(column: 2, row: 0).isEmpty)
    }

    @Test("Attribute-only differences redraw while identical attributes emit nothing")
    func attributeDiff() {
        // -- Arrange --
        var previous = CellGrid(size: CellSize(width: 1, height: 1))
        previous.put("A", width: 1, column: 0, row: 0)
        var next = previous
        next.put("A", width: 1, column: 0, row: 0, attributes: [.bold])

        // -- Act --
        let changed = InlineFrameEncoder.encode(next, previous: previous)
        let unchanged = InlineFrameEncoder.encode(next, previous: next)

        // -- Assert --
        #expect(next != previous)
        #expect(changed == "\r\u{1B}[1mA\u{1B}[22m")
        #expect(unchanged.isEmpty)
    }

    @Test("Explicit blank cells retain attributes and reset them at the write boundary")
    func styledBlank() {
        // -- Arrange --
        var grid = CellGrid(size: CellSize(width: 1, height: 1))
        grid.put(" ", width: 1, column: 0, row: 0, attributes: [.underline])

        // -- Act --
        let output = InlineFrameEncoder.encode(grid, previous: nil)

        // -- Assert --
        #expect(grid[0, 0] == .blank)
        #expect(grid.attributes(column: 0, row: 0) == [.underline])
        #expect(output == "\r\u{1B}[2K\u{1B}[4m \u{1B}[24m")
    }

    @Test("Shared intensity reset preserves surviving bold or dim flags")
    func intensityTransitions() {
        // -- Arrange --
        var grid = CellGrid(size: CellSize(width: 4, height: 1))
        grid.put("A", width: 1, column: 0, row: 0, attributes: [.bold, .dim])
        grid.put("B", width: 1, column: 1, row: 0, attributes: [.bold])
        grid.put("C", width: 1, column: 2, row: 0, attributes: [.dim])
        grid.put("D", width: 1, column: 3, row: 0)

        // -- Act --
        let output = InlineFrameEncoder.encode(grid, previous: nil)

        // -- Assert --
        #expect(output == "\r\u{1B}[2K\u{1B}[1;2mA\u{1B}[22;1mB\u{1B}[22;2mC\u{1B}[22mD")
    }

    @Test("Focus, foreground and all owned attributes reset independently")
    func independentResets() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("X").bold().italic().underline().foregroundStyle(Color.red).focusable())
        let grid = try #require(renderer.render(.now).grid)

        // -- Act --
        let output = InlineFrameEncoder.encode(grid, previous: nil)

        // -- Assert --
        #expect(output == "\r\u{1B}[2K\u{1B}[31m\u{1B}[1;3;4m\u{1B}[7mX\u{1B}[27m\u{1B}[22;23;24m\u{1B}[39m")
        #expect(!output.contains("\u{1B}[0m"))
    }
}
