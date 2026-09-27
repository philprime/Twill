import Foundation
import Testing

@testable import Twill

@Suite("Mounted cell layout")
@MainActor
struct CellLayoutTests {
    @Test("Stacks place children in columns and retain nested spacing")
    func stackLayout() {
        // -- Arrange --
        let root = HStack(spacing: 2) {
            Text("界")
            HStack(spacing: 1) {
                Text("A")
                Text("B")
            }
            EmptyView()
            Text("C")
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 10, height: 1))
        #expect(frame.grid?[0, 0] == .glyph("界", width: 2))
        #expect(frame.grid?[4, 0] == .glyph("A", width: 1))
        #expect(frame.grid?[6, 0] == .glyph("B", width: 1))
        #expect(frame.grid?[9, 0] == .glyph("C", width: 1))
    }

    @Test("Vertical stacks place children on separate rows with spacing")
    func verticalStackLayout() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(spacing: 1) {
                Text("A")
                HStack(spacing: 1) {
                    Text("B")
                    Text("C")
                }
                Text("D")
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 3, height: 5))
        #expect(frame.grid?.snapshotText == "A  \n   \nB C\n   \nD  ")
    }

    @Test("Vertical stacks clip rows outside their proposed height")
    func verticalStackClipping() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(spacing: 1) {
                Text("First")
                Text("Last")
            })

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 5, height: 1))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 5, height: 1))
        #expect(frame.grid?.snapshotText == "First")
    }

    @Test("New proposals re-layout cached content without evaluating bodies or advancing timelines")
    func proposalChanges() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var evaluations = 0
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            evaluations += 1
            return HStack {
                Text("界")
                Text("ABC")
            }
        }
        let renderer = ViewRenderer.make(root)
        let initial = renderer.render(start)

        // -- Act --
        let narrow = renderer.render(start, proposal: ProposedCellSize(width: 4, height: 1))
        let expanded = renderer.render(start, proposal: ProposedCellSize(width: 10, height: 2))

        // -- Assert --
        #expect(evaluations == 1)
        #expect(narrow.grid?.size == CellSize(width: 4, height: 1))
        #expect(narrow.grid?[3, 0] == .glyph("A", width: 1))
        #expect(expanded.grid == initial.grid)
        #expect(narrow.nextUpdate == initial.nextUpdate)
        #expect(expanded.nextUpdate == initial.nextUpdate)
    }

    @Test("A capped main pane leaves room for a neighboring detail pane")
    func cappedPane() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack {
                VStack {
                    Text("Long note title").frame(maxWidth: 6)
                    Text("Short")
                }
                Text("Detail")
            })

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 16, height: 3))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 13, height: 2))
        #expect(frame.grid?.snapshotText == "Long n Detail\nShort        ")
    }

    @Test("A capped frame preserves the order of transparent group children")
    func cappedGroup() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack {
                Group {
                    Text("AB")
                    Text("CDE")
                }
                .frame(maxWidth: 4)
                Text("!")
            })

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 1))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 6, height: 1))
        #expect(frame.grid?.snapshotText == "ABCD !")
    }

    @Test("Flexible panels occupy the viewport and leave a capped sidebar beside a filling detail pane")
    func fillingPanels() {
        // -- Arrange --
        let background = Color(red: 30, green: 30, blue: 30)
        let border = Color(red: 90, green: 90, blue: 90)
        let renderer = ViewRenderer.make(
            VStack(spacing: 1) {
                Text("H").frame(fillWidth: true).backgroundStyle(background)
                Text("Search").frame(fillWidth: true).border(.single, color: border)
                HStack(spacing: 2) {
                    Text("L").frame(width: 8).frame(fillHeight: true).border(.single, color: border)
                    Text("R").frame(fillWidth: true, fillHeight: true).border(.single, color: border)
                }
                .frame(fillHeight: true)
                Text("F").frame(fillWidth: true)
            }
            .backgroundStyle(background))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 30, height: 14))
        let expanded = renderer.render(.now, proposal: ProposedCellSize(width: 40, height: 20))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 30, height: 14))
        #expect(frame.grid?[29, 2] == .glyph("┐", width: 1))
        #expect(frame.grid?[9, 6] == .glyph("┐", width: 1))
        #expect(frame.grid?[12, 6] == .glyph("┌", width: 1))
        #expect(frame.grid?[29, 11] == .glyph("┘", width: 1))
        #expect(frame.grid?[0, 13] == .glyph("F", width: 1))
        #expect(frame.grid?.background(column: 29, row: 13) == background)
        #expect(expanded.grid?.size == CellSize(width: 40, height: 20))
        #expect(expanded.grid?[39, 2] == .glyph("┐", width: 1))
        #expect(expanded.grid?[39, 17] == .glyph("┘", width: 1))
        #expect(expanded.grid?[0, 19] == .glyph("F", width: 1))
    }

    @Test("An empty Text remains a layout item but EmptyView does not")
    func emptyContent() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack {
                Text("")
                EmptyView()
                Text("A")
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 2, height: 1))
        #expect(frame.grid?[0, 0] == .blank)
        #expect(frame.grid?[1, 0] == .glyph("A", width: 1))
        #expect(ViewRenderer.make(EmptyView()).render(.now).grid == nil)
    }
}
