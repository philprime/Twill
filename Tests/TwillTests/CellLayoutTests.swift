import Foundation
import Testing

@testable import Twill

@Suite("Mounted cell layout")
@MainActor
struct CellLayoutTests {
    @Test("Cell geometry constructs rectangles from an origin and size")
    func cellGeometry() {
        // -- Arrange --
        let origin = CellPosition(column: 3, row: 4)
        let size = CellSize(width: 5, height: 6)

        // -- Act --
        let rect = CellRect(origin: origin, size: size)
        let zero = CellRect.zero

        // -- Assert --
        #expect(CellPosition.zero == CellPosition(column: 0, row: 0))
        #expect(rect == CellRect(column: 3, row: 4, width: 5, height: 6))
        #expect(zero == CellRect(column: 0, row: 0, width: 0, height: 0))
    }

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
        #expect(frame.grid?.snapshotText == " A \n   \nB C\n   \n D ")
    }

    @Test("Stacks remain content-sized and center children on the cross axis")
    func centeredStackChildren() {
        // -- Arrange --
        let vertical = ViewRenderer.make(
            VStack {
                Text("A")
                Text("WIDE")
            })
        let horizontal = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                VStack {
                    Text("B")
                    Text("C")
                    Text("D")
                }
            })

        // -- Act --
        let verticalGrid = vertical.render(.now).grid
        let horizontalGrid = horizontal.render(.now).grid

        // -- Assert --
        #expect(verticalGrid?.snapshotText == " A  \nWIDE")
        #expect(horizontalGrid?.snapshotText == " B\nAC\n D")
    }

    @Test("Stack alignment changes child placement, not the stack's size")
    func stackAlignment() {
        // -- Arrange --
        let vertical = ViewRenderer.make(
            VStack(alignment: .trailing) {
                Text("A")
                Text("WIDE")
            })
        let horizontal = ViewRenderer.make(
            HStack(alignment: .bottom, spacing: 0) {
                Text("A")
                VStack {
                    Text("B")
                    Text("C")
                    Text("D")
                }
            })

        // -- Act --
        let verticalGrid = vertical.render(.now).grid
        let horizontalGrid = horizontal.render(.now).grid

        // -- Assert --
        #expect(verticalGrid?.snapshotText == "   A\nWIDE")
        #expect(horizontalGrid?.snapshotText == " B\n C\nAD")
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

    @Test("A flexible frame expands while keeping intrinsic content centered")
    func flexibleFrame() {
        // -- Arrange --
        let background = Color(red: 8, green: 16, blue: 24)
        let renderer = ViewRenderer.make(
            Text("Hi")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .backgroundStyle(background))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 5))
        let intrinsic = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 8, height: 5))
        #expect(frame.grid?[3, 2] == .glyph("H", width: 1))
        #expect(frame.grid?[4, 2] == .glyph("i", width: 1))
        #expect(frame.grid?.background(column: 0, row: 0) == background)
        #expect(intrinsic.grid?.size == CellSize(width: 2, height: 1))
    }

    @Test("Frame alignment positions content without stretching it")
    func alignedFrame() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("Hi").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 8, height: 5))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 8, height: 5))
        #expect(frame.grid?[6, 4] == .glyph("H", width: 1))
        #expect(frame.grid?[7, 4] == .glyph("i", width: 1))
    }

    @Test("Finite frame limits accept space up to their caps")
    func finiteFrameLimits() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("Hi").frame(maxWidth: 6, maxHeight: 3))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 10, height: 5))
        let intrinsic = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 6, height: 3))
        #expect(frame.grid?[2, 1] == .glyph("H", width: 1))
        #expect(intrinsic.grid?.size == CellSize(width: 2, height: 1))
    }

    @Test("A wide framed stack centers its intrinsic children unless alignment changes")
    func wideFramedStack() {
        // -- Arrange --
        let centered = ViewRenderer.make(
            HStack { Text("Hi") }.frame(maxWidth: .infinity))
        let leading = ViewRenderer.make(
            HStack { Text("Hi") }.frame(maxWidth: .infinity, alignment: .leading))

        // -- Act --
        let centerGrid = centered.render(.now, proposal: ProposedCellSize(width: 8, height: 1)).grid
        let leadingGrid = leading.render(.now, proposal: ProposedCellSize(width: 8, height: 1)).grid

        // -- Assert --
        #expect(centerGrid?.snapshotText == "   Hi   ")
        #expect(leadingGrid?.snapshotText == "Hi      ")
    }

    @Test("Flexible panels occupy the viewport and leave a capped sidebar beside a filling detail pane")
    func fillingPanels() {
        // -- Arrange --
        let background = Color(red: 30, green: 30, blue: 30)
        let border = Color(red: 90, green: 90, blue: 90)
        let renderer = ViewRenderer.make(
            VStack(spacing: 1) {
                Text("H").frame(maxWidth: .infinity, alignment: .leading).backgroundStyle(background)
                Text("Search").frame(maxWidth: .infinity, alignment: .leading).border(.single, color: border)
                HStack(spacing: 2) {
                    Text("L").frame(width: 8).frame(maxHeight: .infinity, alignment: .top).border(
                        .single, color: border)
                    Text("R").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .border(.single, color: border)
                }
                .frame(maxHeight: .infinity)
                Text("F").frame(maxWidth: .infinity, alignment: .leading)
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
