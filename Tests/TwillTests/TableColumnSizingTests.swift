import Testing

@testable import Twill

@Suite("Table column sizing")
@MainActor
struct TableColumnSizingTests {
    private struct Item: Identifiable {
        let id = 0
        let name = "LongFileName"
        let count = 7
    }

    @Test("Nested tables resolve independent column widths on every measurement pass")
    func nestedTables() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([Item()], selection: Binding<Int?>(get: { nil }, set: { _ in })) {
                TableColumn("Nested") { _ in
                    Table([Item()], selection: Binding<Int?>(get: { nil }, set: { _ in })) {
                        TableColumn("A") { _ in Text("xx") }
                        TableColumn("B") { _ in Text("y") }
                    }
                }
                TableColumn("Tail") { _ in Text("outer") }
            })

        // -- Act --
        let intrinsic = try #require(renderer.render(.now).grid)
        let expanded = try #require(renderer.drawFrame(proposal: ProposedCellSize(width: 21)))

        // -- Assert --
        #expect(intrinsic.size == CellSize(width: 13, height: 3))
        #expect(intrinsic[5, 1] == .glyph("B", width: 1))
        #expect(intrinsic[5, 2] == .glyph("y", width: 1))
        #expect(intrinsic[8, 1] == .glyph("o", width: 1))
        #expect(expanded.size == CellSize(width: 21, height: 3))
        #expect(expanded[7, 1] == .glyph("B", width: 1))
        #expect(expanded[7, 2] == .glyph("y", width: 1))
        #expect(expanded[12, 1] == .glyph("o", width: 1))
    }

    @Test("Columns preserve content before sharing surplus space")
    func surplusWidth() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([Item()], selection: Binding<Int?>(get: { nil }, set: { _ in })) {
                TableColumn("Name", value: \.name)
                TableColumn("N") { Text("\($0.count)") }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: ProposedCellSize(width: 17)).grid)

        // -- Assert --
        #expect(grid.size.width == 17)
        #expect(grid.snapshotText.split(separator: "\n")[1] == "LongFileName   7 ")
        #expect(grid.isFocused(column: 15, row: 1))
    }

    @Test("Shrinking columns preserves short content instead of wasting its allocated space")
    func constrainedWidth() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([Item()], selection: Binding<Int?>(get: { nil }, set: { _ in })) {
                TableColumn("Name", value: \.name)
                TableColumn("N") { Text("\($0.count)") }
            })
        _ = renderer.render(.now, proposal: ProposedCellSize(width: 17))

        // -- Act --
        let grid = try #require(renderer.drawFrame(proposal: ProposedCellSize(width: 13)))

        // -- Assert --
        #expect(grid.size.width == 13)
        #expect(grid.snapshotText.split(separator: "\n")[1] == "LongFileNa  7")
        #expect(grid.isFocused(column: 12, row: 1))
    }
}
