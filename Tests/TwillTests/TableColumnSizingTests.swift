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
