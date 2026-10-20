import Testing

@testable import Twill

@Suite("Multiline text alignment")
@MainActor
struct MultilineTextAlignmentTests {
    @Test("Explicit rows align within natural text bounds using terminal cells")
    func explicitRows() throws {
        // -- Arrange --
        let leading = ViewRenderer.make(Text("abcd\n界\nx").multilineTextAlignment(.leading))
        let center = ViewRenderer.make(Text("abcd\n界\nx").multilineTextAlignment(.center))
        let trailing = ViewRenderer.make(Text("abcd\n界\nx").multilineTextAlignment(.trailing))

        // -- Act --
        let first = try #require(leading.render(.now).grid)
        let second = try #require(center.render(.now).grid)
        let third = try #require(trailing.render(.now).grid)

        // -- Assert --
        #expect(first.snapshotText == "abcd\n界  \nx   ")
        #expect(second.snapshotText == "abcd\n 界 \n x  ")
        #expect(third.snapshotText == "abcd\n  界\n   x")
        #expect(first.size == second.size && second.size == third.size)
        #expect(third[3, 1] == .continuation)
    }

    @Test("Combining sequences and empty rows retain cell-safe alignment")
    func combiningAndEmptyRows() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("abcd\n\ne\u{301}\n").multilineTextAlignment(.trailing))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 4, height: 4))
        #expect(frame.snapshotText == "abcd\n    \n   e\u{301}\n    ")
        #expect(frame[3, 2] == .glyph("e\u{301}", width: 1))
    }

    @Test("Wrapped rows align without changing their break positions")
    func wrapping() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("one two three").multilineTextAlignment(.trailing))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 5)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 5, height: 3))
        #expect(frame.snapshotText == "  one\n  two\nthree")
    }

    @Test("Nearest settings override inherited alignment independently of other text policies")
    func inheritance() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("abcd\nx")
                Text("abcd\ny").multilineTextAlignment(.leading)
            }.multilineTextAlignment(.trailing).lineBreakMode(.characterWrapping))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "abcd\n   x\nabcd\ny   ")
    }

    @Test("Alignment applies to the visible glyphs after wide-character truncation")
    func truncation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("界界界").lineLimit(1).truncationMode(.middle).multilineTextAlignment(.trailing))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 4)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 4, height: 1))
        #expect(frame[0, 0] == .blank)
        #expect(frame[1, 0] == .glyph("界", width: 2))
        #expect(frame[2, 0] == .continuation)
        #expect(frame[3, 0] == .glyph("…", width: 1))
    }

    @Test("Frame alignment places the text block separately from row alignment")
    func framePlacement() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("abcd\nx").frame(width: 8, alignment: .leading).multilineTextAlignment(.trailing))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "abcd    \n   x    ")
    }

    @Test("Clipped and oversized rows stay at the leading edge without splitting glyphs")
    func clipping() throws {
        // -- Arrange --
        let clipped = ViewRenderer.make(Text("abcdef").lineBreakMode(.clipping).multilineTextAlignment(.trailing))
        let wide = ViewRenderer.make(Text("界A").multilineTextAlignment(.center))

        // -- Act --
        let clippedFrame = try #require(clipped.render(.now, proposal: .init(width: 3)).grid)
        let wideFrame = try #require(wide.render(.now, proposal: .init(width: 1)).grid)
        let empty = wide.render(.now, proposal: .init(width: 0)).grid

        // -- Assert --
        #expect(clippedFrame.snapshotText == "abc")
        #expect(wideFrame.snapshotText == " \nA")
        #expect(empty?.size == .zero)
    }

    @Test("Resize repositions cached rows without reevaluating view bodies")
    func resize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(CountedText { evaluations += 1 })
        let initial = renderer.render(.now, proposal: .init(width: 5))

        // -- Act --
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 7)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 5)))

        // -- Assert --
        #expect(initial.grid?.snapshotText == "  one\n  two\nthree")
        #expect(resized.snapshotText == "one two\n  three")
        #expect(restored == initial.grid)
        #expect(evaluations == 1)
        #expect(initial.nextUpdate == nil)
    }

    private struct CountedText: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Text("one two three").multilineTextAlignment(.trailing)
        }
    }
}
