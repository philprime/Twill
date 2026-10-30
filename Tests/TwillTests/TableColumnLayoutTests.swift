import Testing

@testable import Twill

@Suite("Table column sizing and alignment")
@MainActor
struct TableColumnLayoutTests {
    private struct Row: Identifiable {
        let id: Int
        let name: String
        let count: Int
    }

    @Test("Fixed widths and trailing alignment share header and body geometry")
    func fixedAlignment() throws {
        // -- Arrange --
        let rows = [Row(id: 1, name: "A", count: 12), Row(id: 2, name: "界", count: 3)]
        let renderer = ViewRenderer.make(
            Table(rows) {
                TableColumn("Name", value: \.name).width(4)
                TableColumn("N") { Text("\($0.count)") }.width(.fixed(4)).alignment(.trailing)
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 10, height: 3))
        #expect(grid.snapshotText == "Name     N\nA       12\n界       3")
    }

    @Test("Centered content uses display cells and oversized graphemes stay whole")
    func centeredAndClippedGlyphs() throws {
        // -- Arrange --
        let rows = [Row(id: 1, name: "界", count: 1)]
        let centered = ViewRenderer.make(
            Table(rows) {
                TableColumn("N", value: \.name).width(6).alignment(.center)
            })
        let clipped = ViewRenderer.make(Table(rows) { TableColumn("X", value: \.name).width(1) })

        // -- Act --
        let wide = try #require(centered.render(.now).grid)
        let narrow = try #require(clipped.render(.now).grid)

        // -- Assert --
        #expect(wide.snapshotText == "  N   \n  界  ")
        #expect(narrow.snapshotText == "X\n ")
    }

    @Test("Hard fixed and flexible bounds clip scarce space and leave capped surplus unused")
    func allocationBounds() {
        // -- Arrange --
        let layout = TableLayout(columns: [.fixed(4), .flexible(minimum: 2, maximum: 6)])
        let sizes = [CellSize(width: 10, height: 1), CellSize(width: 2, height: 1)]

        // -- Act --
        let natural = layout.columnWidths(in: nil, subviews: sizes)
        let scarce = layout.columnWidths(in: 3, subviews: sizes)
        let excess = layout.columnWidths(in: 20, subviews: sizes)

        // -- Assert --
        #expect(natural == [4, 2])
        #expect(scarce == [4, 2])
        #expect(excess == [4, 6])
    }

    @Test("Empty automatic columns retain their minimum slots under zero-width clipping")
    func emptyColumns() {
        // -- Arrange --
        let layout = TableLayout(columns: [.automatic, .automatic])

        // -- Act --
        let widths = layout.columnWidths(in: 0, subviews: [.zero, .zero])

        // -- Assert --
        #expect(widths == [1, 1])
    }

    @Test(
        "Zero-width column policies preserve their bounds during allocation",
        arguments: [TableColumnWidth.fixed(0), .flexible(), .flexible(minimum: 0, maximum: 0)]
    )
    func zeroWidthAllocation(_ policy: TableColumnWidth) {
        // -- Arrange --
        let layout = TableLayout(columns: [policy])

        // -- Act --
        let widths = layout.columnWidths(in: 0, subviews: [CellSize(width: 8, height: 1)])

        // -- Assert --
        #expect(widths == [0])
    }

    @Test("A default flexible minimum shares space and permits zero-width clipping")
    func defaultFlexibleMinimum() {
        // -- Arrange --
        let layout = TableLayout(columns: [.flexible()])
        let sizes = [CellSize(width: 8, height: 1)]

        // -- Act --
        let natural = layout.columnWidths(in: nil, subviews: sizes)
        let bounded = layout.columnWidths(in: 6, subviews: sizes)

        // -- Assert --
        #expect(natural == [8])
        #expect(bounded == [6])
    }

    @Test("A zero-width column hides its content without shifting the following column slot")
    func hiddenColumn() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([Row(id: 1, name: "Hidden", count: 2)]) {
                TableColumn("Hidden", value: \.name).width(0)
                TableColumn("N") { Text("\($0.count)") }.width(1)
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 3, height: 2))
        #expect(grid.snapshotText == "  N\n  2")
    }

    @Test("Multiline cells keep top alignment and shared column slots")
    func multiline() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([Row(id: 1, name: "ab\nc", count: 1)]) {
                TableColumn("L", value: \.name).width(3)
                TableColumn("R") { Text("\($0.count)") }.width(3).alignment(.trailing)
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "L      R\nab     1\nc       ")
    }

    @Test("Resize reuses cached content and recomputes header and row offsets together")
    func resizing() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(CountedTable(evaluated: { evaluations += 1 }))
        let wide = try #require(renderer.render(.now, proposal: .init(width: 12)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 8)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 12)))

        // -- Assert --
        #expect(wide[10, 0] == .glyph("N", width: 1))
        #expect(wide[10, 1] == .glyph("2", width: 1))
        #expect(narrow[7, 0] == .glyph("N", width: 1))
        #expect(narrow[7, 2] == .glyph("2", width: 1))
        #expect(restored == wide)
        #expect(evaluations == 1)
    }

    private struct CountedTable: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Table([Row(id: 1, name: "abcdef", count: 2)]) {
                TableColumn("Text", value: \.name).width(.flexible(minimum: 2, maximum: 6))
                TableColumn("N") { Text("\($0.count)") }.width(3).alignment(.trailing)
            }
        }
    }
}
