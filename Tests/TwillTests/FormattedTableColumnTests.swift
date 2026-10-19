import Foundation
import Testing

@testable import Twill

@Suite("Formatted table values")
@MainActor
struct FormattedTableColumnTests {
    private struct Row: Identifiable {
        let id: Int
        let value: Int
    }

    @Test("Formatted text retains numeric comparisons and caller-owned row order")
    func sortSemantics() throws {
        // -- Arrange --
        let rows = [Row(id: 1, value: 10), Row(id: 2, value: 2)]
        var order: [KeyPathComparator<Row>] = []
        let renderer = ViewRenderer.make(
            Table(rows, sortOrder: Binding(get: { order }, set: { order = $0 })) {
                TableColumn("Count", value: \.value, format: { "\($0) units" }).width(10).alignment(.trailing)
            })
        let grid = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        let comparator = try #require(order.first)
        let sorted = rows.sorted(using: order)

        // -- Assert --
        #expect(grid.snapshotText.contains("10 units") && grid.snapshotText.contains("2 units"))
        #expect(comparator.compare(rows[0], rows[1]) == .orderedDescending)
        #expect(sorted.map(\.value) == [2, 10])
        #expect(rows.map(\.value) == [10, 2])
    }

    @Test("Changing a formatter retains keyed rows and updated activation payloads")
    func formatterUpdates() throws {
        // -- Arrange --
        var activated: [Int] = []
        func table(_ suffix: String) -> some View {
            Table([Row(id: 1, value: 3)], selection: .constant(nil)) {
                TableColumn("Value", value: \.value, format: { "\($0) \(suffix)" })
            }.onActivate { activated.append($0.value) }
        }
        let renderer = ViewRenderer.make(table("old"))
        _ = renderer.render(.now)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(table("new"), at: .now)
        let grid = try #require(renderer.render(.now).grid)
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.snapshotText.contains("3 new"))
        #expect(retained && activated == [3])
    }

    @Test("Formatters receive the typed source value and their output remains terminal-safe")
    func typedInput() throws {
        // -- Arrange --
        var inputs: [Int] = []
        let renderer = ViewRenderer.make(
            Table([Row(id: 1, value: 42)]) {
                TableColumn(
                    "Value", value: \.value,
                    format: {
                        inputs.append($0)
                        return "\u{1B}[2J\($0)"
                    })
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(inputs == [42])
        #expect(!grid.snapshotText.contains("\u{1B}"))
        #expect(grid.snapshotText.contains("42"))
    }
}
