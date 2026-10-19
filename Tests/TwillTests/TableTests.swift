import Foundation
import Testing

@testable import Twill

@Suite("Tables")
@MainActor
struct TableTests {
    private struct Item: Identifiable {
        let id: Int
        let name: String
        let count: Int
    }

    private let items = [Item(id: 10, name: "A", count: 12), Item(id: 20, name: "Long", count: 3)]

    @Test("Headers and custom cells share intrinsic column widths across every row")
    func alignedColumns() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table(items, selection: Binding(get: { nil as Int? }, set: { _ in })) {
                TableColumn("Name", value: \.name)
                TableColumn("Count") { item in Text("\(item.count)") }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Name  Count\nA     12   \nLong  3    ")
        #expect(!grid.isFocused(column: 0, row: 0))
        #expect(grid.isFocused(column: 0, row: 1))
        #expect(!grid.isFocused(column: 0, row: 2))
    }

    @Test("Row navigation selects IDs, clamps at boundaries, and submits the selected row")
    func navigation() {
        // -- Arrange --
        var selection: Int? = 10
        var submitted: [Int?] = []
        let renderer = ViewRenderer.make(
            Table(items, selection: Binding(get: { selection }, set: { selection = $0 })) {
                TableColumn("Name", value: \.name)
            }
            .onSubmit { submitted.append(selection) })
        _ = renderer.render(.now)

        // -- Act --
        let down = renderer.handle(.arrowDown)
        let boundary = renderer.handle(.arrowDown)
        let enter = renderer.handle(.enter)
        _ = renderer.handle(.home)
        let first = selection
        _ = renderer.handle(.end)
        _ = renderer.handle(.arrowUp)

        // -- Assert --
        #expect(down && boundary && enter)
        #expect(submitted == [20])
        #expect(first == 10)
        #expect(selection == 10)
    }

    @Test("Selection is revealed on mount, navigation, and external changes within the table pane")
    func scrolling() throws {
        // -- Arrange --
        var selection: Int? = 3
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let rows = (0..<6).map { Item(id: $0, name: "Row \($0)", count: $0) }
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                Table(rows, selection: Binding(get: { selection }, set: { selection = $0 })) {
                    TableColumn("Name", value: \.name)
                }.frame(height: 2)
            })

        // -- Act --
        let initial = try #require(renderer.render(start).grid)
        _ = renderer.handle(.arrowDown)
        let moved = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        selection = 0
        let external = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(initial.snapshotText == "Row 2\nRow 3")
        #expect(moved.snapshotText == "Row 3\nRow 4")
        #expect(external.snapshotText == "Row 0\nRow 1")
    }

    @Test("Changing panes preserves selection and returning restores the table control")
    func panes() throws {
        // -- Arrange --
        var selection: Int? = 20
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading, spacing: 0) {
                Table(items, selection: Binding(get: { selection }, set: { selection = $0 })) {
                    TableColumn("Name", value: \.name)
                }.frame(height: 3)
                ScrollView { Text("Other").focusable() }.frame(height: 1)
            })
        _ = renderer.render(.now)

        // -- Act --
        let switched = renderer.handle(.tab)
        let away = try #require(renderer.render(.now).grid)
        let returned = renderer.handle(.shiftTab)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)

        // -- Assert --
        #expect(switched && returned)
        #expect(away.isFocused(column: 0, row: 2))
        #expect(away.isFocused(column: 0, row: 3))
        #expect(selection == 10)
    }

    @Test("Empty and filtered tables do not overwrite stored selection or submit stale rows")
    func missingSelection() throws {
        // -- Arrange --
        var selection: Int? = 99
        var submissions: [Int?] = []
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let renderer = ViewRenderer.make(
            Table(items, selection: binding) { TableColumn("Name", value: \.name) }
                .onSubmit { submissions.append(selection) })
        let empty = ViewRenderer.make(
            Table([Item](), selection: binding) { TableColumn("Name", value: \.name) }
                .onSubmit { submissions.append(selection) })

        // -- Act --
        let fallback = try #require(renderer.render(.now).grid)
        let stored = selection
        _ = renderer.handle(.enter)
        let emptyGrid = try #require(empty.render(.now).grid)
        let handled = empty.handle(.enter)
        _ = empty.handle(.arrowDown)

        // -- Assert --
        #expect(stored == 99)
        #expect(fallback.isFocused(column: 0, row: 1))
        #expect(selection == 10)
        #expect(submissions == [10])
        #expect(handled)
        #expect(emptyGrid.snapshotText == "Name")
    }

    @Test("Constrained columns stay aligned while wide text wraps in terminal cells")
    func constrainedColumns() throws {
        // -- Arrange --
        let rows = [Item(id: 0, name: "界界界", count: 12), Item(id: 1, name: "A", count: 3)]
        let renderer = ViewRenderer.make(
            Table(rows, selection: Binding(get: { nil as Int? }, set: { _ in })) {
                TableColumn("Name", value: \.name)
                TableColumn("N") { Text("\($0.count)") }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: ProposedCellSize(width: 8)).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 8, height: 4))
        #expect(grid.snapshotText == "Name  N \n界界  12\n界      \nA     3 ")
    }

    @Test("Empty cells retain their column slots and empty rows retain their height")
    func emptyCells() throws {
        // -- Arrange --
        let binding = Binding<Int?>(get: { nil }, set: { _ in })
        let renderer = ViewRenderer.make(
            Table(items, selection: binding) {
                TableColumn("Empty") { _ in EmptyView() }
                TableColumn("Name", value: \.name)
            })
        let emptyRows = ViewRenderer.make(
            Table(items, selection: binding) {
                TableColumn("Value") { _ in EmptyView() }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        let blank = try #require(emptyRows.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Empty  Name\n       A   \n       Long")
        #expect(grid.isFocused(column: 7, row: 1))
        #expect(blank.snapshotText == "Value\n     \n     ")
    }

    @Test("Cell key handlers cannot intercept keys intended for the table")
    func cellKeyIsolation() {
        // -- Arrange --
        var cellKeys = 0
        var tableKeys = 0
        let renderer = ViewRenderer.make(
            Table(items.prefix(1), selection: Binding(get: { nil as Int? }, set: { _ in })) {
                TableColumn("Name") { item in
                    Text(item.name).onKeyPress { _ in
                        cellKeys += 1
                        return .handled
                    }
                }
            }
            .onKeyPress { _ in
                tableKeys += 1
                return .handled
            })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.g)

        // -- Assert --
        #expect(handled)
        #expect(cellKeys == 0)
        #expect(tableKeys == 1)
    }

    private struct SortableItems: View {
        let items: [Item]
        @State private var selection: Int? = 20
        @State private var sortOrder: [KeyPathComparator<Item>] = []
        let didSort: @MainActor ([KeyPathComparator<Item>]) -> Void

        var body: some View {
            Table(
                items, selection: $selection,
                sortOrder: Binding(
                    get: { sortOrder },
                    set: {
                        sortOrder = $0
                        didSort($0)
                    })
            ) {
                TableColumn("Name", value: \.name)
                TableColumn("Count", value: \.count) { item in Text("\(item.count)") }
            }
        }
    }

    @Test("Headers and rows remain reachable after scrolling without changing selection on focus moves")
    func headerNavigation() throws {
        // -- Arrange --
        var orders: [[KeyPathComparator<Item>]] = []
        let renderer = ViewRenderer.make(SortableItems(items: items) { orders.append($0) }.frame(height: 2))
        let header = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let rows = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        let returned = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowDown)
        let revealed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.home)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)
        let firstHeader = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(header.snapshotText == "Name ↕  Count ↕\nA       12     ")
        #expect(rows.snapshotText == "A       12     \nLong    3      ")
        #expect(returned.snapshotText == header.snapshotText)
        #expect(returned.isFocused(column: 8, row: 0))
        #expect(revealed.snapshotText == rows.snapshotText)
        #expect(firstHeader.isFocused(column: 0, row: 0))
        #expect(orders.isEmpty)
    }

    @Test("Header activation updates sort comparators without reordering caller-owned data")
    func sorting() throws {
        // -- Arrange --
        var orders: [[KeyPathComparator<Item>]] = []
        let renderer = ViewRenderer.make(SortableItems(items: items) { orders.append($0) })
        _ = renderer.render(.now)

        // -- Act --
        let first = renderer.handle(.enter)
        let ascending = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.space)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowRight)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let numeric = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(first)
        #expect(orders.count == 3)
        #expect(orders.first?.first?.keyPath == \Item.name)
        #expect(orders.first?.first?.order == .forward)
        #expect(orders.dropFirst().first?.first?.order == .reverse)
        #expect(orders.last?.first?.keyPath == \Item.count)
        #expect(orders.last?.last?.keyPath == \Item.name)
        #expect(ascending.snapshotText == "Name ↑  Count ↕\nA       12     \nLong    3      ")
        #expect(numeric.snapshotText == "Name ↓  Count ↑\nA       12     \nLong    3      ")
        #expect(numeric.isFocused(column: 8, row: 0))
        #expect(numeric.isFocused(column: 0, row: 2))
    }
}
