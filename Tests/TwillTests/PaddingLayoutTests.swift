import Foundation
import Testing

@testable import Twill

@Suite("Mounted padding layout")
@MainActor
struct PaddingLayoutTests {
    @Test("Default padding adds one blank cell around content")
    func defaultPadding() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").padding())

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 3, height: 3))
        #expect(frame.grid?.snapshotText == "   \n A \n   ")
    }

    @Test("Explicit padding uses the requested cell count on every edge")
    func uniformPadding() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").padding(2))

        // -- Act --
        let grid = renderer.render(.now).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 5, height: 5))
        #expect(grid?[2, 2] == .glyph("A", width: 1))
        #expect(grid?[1, 2] == .blank)
    }

    @Test("Edge sets pad only the selected sides")
    func selectedEdgePadding() {
        // -- Arrange --
        let horizontal = ViewRenderer.make(Text("AB").padding(.horizontal, 2))
        let corners = ViewRenderer.make(Text("A").padding([.bottom, .trailing], 1))

        // -- Act --
        let horizontalGrid = horizontal.render(.now).grid
        let cornerGrid = corners.render(.now).grid

        // -- Assert --
        #expect(horizontalGrid?.snapshotText == "  AB  ")
        #expect(cornerGrid?.snapshotText == "A \n  ")
    }

    @Test("Insets give each edge an independent cell count")
    func asymmetricPadding() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("A").padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 1)))

        // -- Act --
        let grid = renderer.render(.now).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 4, height: 2))
        #expect(grid?.snapshotText == "    \n  A ")
    }

    @Test("Padding can separate content from a border and the border from its container")
    func paddingAroundBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").padding().border(.single, color: Color.white).padding())

        // -- Act --
        let grid = renderer.render(.now).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 7, height: 7))
        #expect(grid?[0, 0] == .blank)
        #expect(grid?[1, 1] == .glyph("┌", width: 1))
        #expect(grid?[3, 3] == .glyph("A", width: 1))
        #expect(grid?[5, 5] == .glyph("┘", width: 1))
    }

    @Test("Background styling covers only padding inside that modifier")
    func paddingBackgroundOrder() {
        // -- Arrange --
        let color = Color(red: 15, green: 25, blue: 35)
        let inner = ViewRenderer.make(Text("A").backgroundStyle(color).padding())
        let outer = ViewRenderer.make(Text("A").padding().backgroundStyle(color))

        // -- Act --
        let innerGrid = inner.render(.now).grid
        let outerGrid = outer.render(.now).grid

        // -- Assert --
        #expect(innerGrid?.background(column: 0, row: 0) == nil)
        #expect(innerGrid?.background(column: 1, row: 1) == color)
        #expect(outerGrid?.background(column: 0, row: 0) == color)
    }

    @Test("Padding adds to stack spacing")
    func paddedStackChild() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 1) {
                Text("A").padding(.horizontal, 1)
                Text("B")
            })

        // -- Act --
        let grid = renderer.render(.now).grid

        // -- Assert --
        #expect(grid?.snapshotText == " A  B")
    }

    @Test("Padding passes remaining proposed cells to a flexible frame")
    func paddedFlexibleFrame() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").frame(maxWidth: .infinity, alignment: .leading).padding())

        // -- Act --
        let grid = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 3)).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 8, height: 3))
        #expect(grid?.snapshotText == "        \n A      \n        ")
    }

    @Test("Padding leaves flexible space for transparent group children")
    func paddedGroupWithFlexibleChild() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Group {
                Text("A").frame(maxWidth: .infinity, alignment: .leading)
                Text("B")
            }
            .padding())

        // -- Act --
        let grid = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 3)).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 8, height: 3))
        #expect(grid?.snapshotText == "        \n A    B \n        ")
    }

    @Test("Padding clips safely when the proposal is smaller than its insets")
    func tightPadding() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").padding(2))

        // -- Act --
        let grid = renderer.render(.now, proposal: ProposedCellSize(width: 3, height: 1)).grid

        // -- Assert --
        #expect(grid?.size == CellSize(width: 3, height: 1))
        #expect(grid?.snapshotText == "   ")
    }
}
