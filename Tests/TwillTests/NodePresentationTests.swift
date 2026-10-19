import Testing

@testable import Twill

@Suite("Node-local presentation")
@MainActor
struct NodePresentationTests {
    @Test("Border presentation measures and clips its content without a mounted tree")
    func borderContext() {
        // -- Arrange --
        let presentation = NodePresentation.border(
            glyphs: Border.single.glyphs, style: ResolvedStyle(color: nil, attributes: [.dim]),
            title: TextDrawing("界界界界界"))
        var proposals: [ProposedCellSize] = []

        // -- Act --
        let size = presentation.sizeThatFits(ProposedCellSize(width: 9, height: 5)) { proposal in
            proposals.append(proposal)
            return TextDrawing("ABC").sizeThatFits(proposal)
        }
        var drawing = DrawingContext(size: size)
        presentation.draw(
            in: &drawing,
            context: NodePresentationContext(
                size: size, isFocused: false, isDirectlyFocused: false,
                drawChildren: { TextDrawing("ABC").draw(in: &$0) }))

        // -- Assert --
        #expect(proposals.count == 1)
        #expect(proposals.first?.width == 7)
        #expect(proposals.first?.height == 3)
        #expect(size == CellSize(width: 9, height: 3))
        #expect(drawing.grid[0, 0] == .glyph("┌", width: 1))
        #expect(drawing.grid[8, 0] == .glyph("┐", width: 1))
        #expect(drawing.grid[1, 1] == .glyph("A", width: 1))
        #expect(drawing.grid[3, 1] == .glyph("C", width: 1))
        #expect(drawing.grid.attributes(column: 0, row: 0) == [.dim])
        #expect(drawing.grid.attributes(column: 1, row: 1).isEmpty)
    }

    @Test("Scroll presentation measures unconstrained content and clips it at the mounted offset")
    func scrollContext() {
        // -- Arrange --
        let presentation = NodePresentation.scroll(offset: 1, contentHeight: 3, indicators: .hidden)
        var proposedHeight: Int? = -1

        // -- Act --
        let size = presentation.sizeThatFits(ProposedCellSize(width: 4, height: 1)) { proposal in
            proposedHeight = proposal.height
            return CellSize(width: 4, height: 3)
        }
        var drawing = DrawingContext(size: size)
        presentation.draw(
            in: &drawing,
            context: NodePresentationContext(
                size: size, isFocused: false, isDirectlyFocused: false,
                drawChildren: { content in
                    content.draw("A", width: 1, column: 0, row: 0)
                    content.draw("B", width: 1, column: 0, row: 1)
                    content.draw("C", width: 1, column: 0, row: 2)
                }))

        // -- Assert --
        #expect(proposedHeight == nil)
        #expect(size == CellSize(width: 4, height: 1))
        #expect(drawing.grid.snapshotText == "B   ")
    }
}
