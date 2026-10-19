import Testing

@testable import Twill

@Suite("Multiline Text")
@MainActor
struct TextWrappingTests {
    @Test("Explicit LF and CRLF boundaries preserve empty and trailing lines")
    func logicalLines() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A\n\n界\r\n"))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 2, height: 4))
        #expect(frame.snapshotText == "A \n  \n界\n  ")
    }

    @Test("Finite width wraps words and discards only separators at wrapped boundaries")
    func words() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("one  two three"))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 7)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 5, height: 3))
        #expect(frame.snapshotText == "one  \ntwo  \nthree")
    }

    @Test("Whitespace that fits is preserved and unspecified width does not wrap")
    func naturalWidth() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("  one  two  \nx"))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 12, height: 2))
        #expect(frame.snapshotText == "  one  two  \nx           ")
    }

    @Test("Long words wrap at grapheme boundaries, including wide and combining characters")
    func longWords() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A界e\u{301}👩‍💻Z"))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 3)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 3, height: 3))
        #expect(frame[1, 0] == .glyph("界", width: 2))
        #expect(frame[2, 0] == .continuation)
        #expect(frame[0, 1] == .glyph("e\u{301}", width: 1))
        #expect(frame[1, 1] == .glyph("👩‍💻", width: 2))
        #expect(frame[2, 1] == .continuation)
        #expect(frame[0, 2] == .glyph("Z", width: 1))
    }

    @Test("A glyph wider than the viewport occupies a clipped row and is never split")
    func oversizedGlyph() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("界A"))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 1)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 1, height: 2))
        #expect(frame[0, 0] == .blank)
        #expect(frame[0, 1] == .glyph("A", width: 1))
    }

    @Test("Other control characters and standalone marks retain safe rendering")
    func sanitization() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A\u{1B}[2J\tB\rC\n\u{301}\u{200B}"))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 9, height: 2))
        #expect(frame.snapshotText == "A [2J B C\n◌\u{301}        ")
        #expect(frame[0, 1] == .glyph("◌\u{301}", width: 1))
    }

    @Test("Zero width or height draws no glyphs and positive height clips complete rows")
    func constrainedHeight() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("abcd efgh"))

        // -- Act --
        let emptyWidth = renderer.render(.now, proposal: .init(width: 0)).grid
        let emptyHeight = renderer.render(.now, proposal: .init(width: 4, height: 0)).grid
        let clipped = try #require(renderer.render(.now, proposal: .init(width: 4, height: 1)).grid)

        // -- Assert --
        #expect(emptyWidth?.size == .zero)
        #expect(emptyHeight?.size.height == 0)
        #expect(clipped.size == CellSize(width: 4, height: 1))
        #expect(clipped.snapshotText == "abcd")
    }

    @Test("Empty logical lines retain their measured height")
    func emptyLines() throws {
        // -- Arrange --
        let empty = ViewRenderer.make(Text(""))
        let lines = ViewRenderer.make(Text("\n\n"))

        // -- Act --
        let emptyFrame = try #require(empty.render(.now).grid)
        let linesFrame = try #require(lines.render(.now).grid)

        // -- Assert --
        #expect(emptyFrame.size == CellSize(width: 0, height: 1))
        #expect(linesFrame.size == CellSize(width: 0, height: 3))
    }

    @Test("Measured wrapping remains stable at the resulting drawing width")
    func measurementConsistency() {
        // -- Arrange --
        let texts = ["one  two three", "   abc def", "abc   ", "a 界 b", "界", "👩‍💻x", "ab\ncd"]

        // -- Act --
        let sizes = texts.flatMap { text in
            (1...12).map { width -> (CellSize, CellSize) in
                let drawing = MultilineTextDrawing(text)
                let measured = drawing.sizeThatFits(.init(width: width))
                return (measured, drawing.sizeThatFits(.init(width: measured.width)))
            }
        }

        // -- Assert --
        for (measured, redrawn) in sizes { #expect(measured == redrawn) }
    }

    @Test("Vertical composition offers its finite width to ordinary text children")
    func verticalComposition() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("one two three")
                Text("end")
            })

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 5)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 5, height: 4))
        #expect(frame.snapshotText == "one  \ntwo  \nthree\nend  ")
    }

    private struct CountedText: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Text("one two three")
        }
    }

    @Test("Resize reflows cached descriptions without reevaluating bodies or scheduling work")
    func resize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(CountedText { evaluations += 1 })
        let wide = renderer.render(.now, proposal: .init(width: 13))

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 5)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 13)))

        // -- Assert --
        #expect(wide.grid?.snapshotText == "one two three")
        #expect(narrow.snapshotText == "one  \ntwo  \nthree")
        #expect(restored.snapshotText == "one two three")
        #expect(evaluations == 1)
        #expect(wide.nextUpdate == nil)
    }
}
