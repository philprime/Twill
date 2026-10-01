import Foundation
import Testing

@testable import Twill

@Suite("Vertical grid layout")
@MainActor
struct LazyVGridTests {
    @Test("Flexible columns fill the proposed width and wrap items into rows")
    func flexibleColumns() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 1) {
                ForEach(["One", "Two", "Three", "Four"], id: \.self) { name in
                    Text(name)
                }
            }
        )

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 20))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 20, height: 3))
        #expect(frame.grid?.snapshotText == "One    Two    Three \n                    \nFour                ")
    }

    @Test("Changing the proposed width reflows columns without rebuilding view content")
    func resizedGrid() {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(
            BodyProbe {
                evaluations += 1
                return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(["ABCD", "EF", "G"], id: \.self) { Text($0) }
                }
            }
        )

        // -- Act --
        let wide = renderer.render(.now, proposal: ProposedCellSize(width: 11))
        let narrow = renderer.render(.now, proposal: ProposedCellSize(width: 5))

        // -- Assert --
        #expect(wide.grid?.snapshotText == "ABCD  EF   \n           \nG          ")
        #expect(narrow.grid?.snapshotText == "AB EF\n     \nG    ")
        #expect(evaluations == 1)
    }

    @Test("Column bounds constrain flexible cell widths")
    func columnBounds() {
        // -- Arrange --
        let capped = ViewRenderer.make(
            LazyVGrid(columns: [GridItem(.flexible(minimum: 2, maximum: 3)), GridItem(.flexible(maximum: 10))]) {
                Text("X")
                Text("Y")
            }
        )
        let narrow = ViewRenderer.make(
            LazyVGrid(columns: [GridItem(.flexible(minimum: 2)), GridItem(.flexible(minimum: 2))]) {
                Text("A")
                Text("B")
            }
        )

        // -- Act --
        let cappedFrame = capped.render(.now, proposal: ProposedCellSize(width: 20))
        let narrowFrame = narrow.render(.now, proposal: ProposedCellSize(width: 3))

        // -- Assert --
        #expect(cappedFrame.grid?.size == CellSize(width: 14, height: 1))
        #expect(cappedFrame.grid?.snapshotText == "X   Y         ")
        #expect(narrowFrame.grid?.snapshotText == "A  ")
    }

    private struct BodyProbe<Content: View>: View {
        let makeContent: @MainActor () -> Content
        var body: some View { makeContent() }
    }
}
