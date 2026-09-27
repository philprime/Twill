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
