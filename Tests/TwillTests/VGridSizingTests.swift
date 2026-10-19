import Testing

@testable import Twill

@Suite("Eager grid sizing")
@MainActor
struct VGridSizingTests {
    @Test("Mixed fixed and capped flexible columns respect independent column spacing")
    func mixedColumns() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VGrid(
                columns: [GridItem(.fixed(2)), GridItem(.flexible(minimum: 1, maximum: 3))],
                rowSpacing: 0, columnSpacing: 2
            ) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            })

        // -- Act --
        let natural = try #require(renderer.render(.now).grid)
        let wide = try #require(renderer.drawFrame(proposal: .init(width: 10)))

        // -- Assert --
        #expect(natural.snapshotText == "A   B\nC   D")
        #expect(wide.snapshotText == "A   B  \nC   D  ")
    }

    @Test("Row spacing is independent from column spacing")
    func rowSpacing() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VGrid(
                columns: [GridItem(.fixed(2)), GridItem(.fixed(2))],
                rowSpacing: 2, columnSpacing: 0
            ) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "A B \n    \n    \nC D ")
    }

    @Test("Fixed columns retain their dimensions under scarce clipping")
    func scarceSpace() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VGrid(
                columns: [GridItem(.fixed(4)), GridItem(.fixed(2))],
                rowSpacing: 0, columnSpacing: 1
            ) {
                Text("A")
                Text("B")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 3)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "A  ")
    }

    @Test("Adaptive layouts use a sole descriptor and reflow cached cells")
    func adaptiveColumns() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VGrid(
                columns: [GridItem(.adaptive(minimum: 3))],
                rowSpacing: 0, columnSpacing: 2
            ) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            })
        let natural = try #require(renderer.render(.now).grid)

        // -- Act --
        let wide = try #require(renderer.drawFrame(proposal: .init(width: 13)))
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 8)))

        // -- Assert --
        #expect(natural.snapshotText == "A  \nB  \nC  \nD  ")
        #expect(wide.snapshotText == "A    B    C  \nD            ")
        #expect(narrow.snapshotText == "A    B  \nC    D  ")
    }

    @Test("Zero fixed and flexible widths are valid allocations")
    func zeroWidths() {
        // -- Arrange --
        let layout = GridLayout(
            columns: [GridItem(.fixed(0)), GridItem(.flexible(minimum: 0, maximum: 0))],
            rowSpacing: 0, columnSpacing: 0)

        // -- Act --
        let widths = layout.columnWidths(
            in: 0, subviews: [CellSize(width: 1, height: 1), CellSize(width: 1, height: 1)])

        // -- Assert --
        #expect(widths == [0, 0])
    }

    @Test("All offscreen descriptions mount eagerly without scheduling static content")
    func eagerMounting() {
        // -- Arrange --
        var evaluated: [Int] = []
        let renderer = ViewRenderer.make(
            VGrid(columns: [GridItem(.fixed(1))], rowSpacing: 0) {
                ForEach(0..<10, id: \.self) { value in
                    evaluated.append(value)
                    return Text("\(value)")
                }
            }.frame(height: 1))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(evaluated == Array(0..<10))
        #expect(frame.grid?.snapshotText == "0")
        #expect(frame.nextUpdate == nil)
    }

    @Test("Zero table width policies agree with grid allocation")
    func zeroTableWidths() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([1], id: \.self) {
                TableColumn("A") { Text("\($0)") }.width(0)
                TableColumn("B") { Text("\($0)") }.width(.flexible(maximum: 0))
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 0)).grid)

        // -- Assert --
        #expect(grid.size.width == 0)
    }
}
