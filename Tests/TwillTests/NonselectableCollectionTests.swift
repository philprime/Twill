import Foundation
import Testing

@testable import Twill

@Suite("Nonselectable collections and explicit table IDs")
@MainActor
struct NonselectableCollectionTests {
    private enum Kind: CaseIterable { case list, table }
    private struct Entry {
        let key: Int
        let name: String
    }
    private let entries = [Entry(key: 1, name: "One"), Entry(key: 2, name: "Two")]

    @ViewBuilder
    private func display(_ kind: Kind, action: @escaping @MainActor (Entry) -> Void) -> some View {
        switch kind {
        case .list:
            List(entries, id: \.key) { Text($0.name) }.onActivate(action)
        case .table:
            Table(entries, id: \.key) { TableColumn("Name", value: \.name) }.onActivate(action)
        }
    }

    @Test("Omitting selection gives static rows without collection activation or submission")
    func displayOnly() throws {
        // -- Arrange --
        for kind in Kind.allCases {
            var calls = 0
            let renderer = ViewRenderer.make(display(kind, action: { _ in calls += 1 }).onSubmit { calls += 1 })

            // -- Act --
            let grid = try #require(renderer.render(.now).grid)
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(grid.snapshotText.contains("One") && grid.snapshotText.contains("Two"))
            #expect((0..<grid.size.height).allSatisfy { !grid.isFocused(column: 0, row: $0) })
            #expect(calls == 0)
        }
    }

    @Test("Empty display-only construction cannot activate collection items")
    func emptyCollections() {
        // -- Arrange --
        var calls = 0
        let list = ViewRenderer.make(List([Entry](), id: \.key) { Text($0.name) }.onActivate { _ in calls += 1 })
        let table = ViewRenderer.make(
            Table([Entry](), id: \.key) { TableColumn("Name", value: \.name) }.onActivate { _ in calls += 1 })
        _ = list.render(.now)
        _ = table.render(.now)

        // -- Act --
        _ = list.handle(.enter)
        _ = table.handle(.enter)

        // -- Assert --
        #expect(calls == 0)
    }

    @Test("Embedded row controls use ordinary Tab traversal and their own activation")
    func rowControls() {
        // -- Arrange --
        var actions: [Int] = []
        var collectionCalls = 0
        let renderer = ViewRenderer.make(
            List(entries, id: \.key) { entry in Button(entry.name) { actions.append(entry.key) } }
                .onActivate { _ in collectionCalls += 1 })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == [1, 2])
        #expect(collectionCalls == 0)
    }

    @Test("Explicit table IDs support selectable non-Identifiable elements and typed columns")
    func explicitTableIDs() {
        // -- Arrange --
        var selection: Int?
        var activated: [Int] = []
        let table: Table<[Entry], Int, Text> = Table(
            entries, id: \.key,
            selection: Binding(get: { selection }, set: { selection = $0 })
        ) {
            TableColumn("Name") { return Text($0.name) }
        }.onActivate { activated.append($0.key) }
        let renderer = ViewRenderer.make(table)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(selection == 2)
        #expect(activated == [2])
    }

    @Test("Display-only tables retain sortable headers and independently interactive cells")
    func sortableDisplay() {
        // -- Arrange --
        var sorted = 0
        var activated: [Int] = []
        let renderer = ViewRenderer.make(
            Table(entries, id: \.key, sortOrder: Binding(get: { [] }, set: { _ in sorted += 1 })) {
                TableColumn("Name", value: \.name) { entry in
                    Button(entry.name) { activated.append(entry.key) }
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(sorted == 1)
        #expect(activated == [1])
    }

    private struct StatefulRow: View {
        @State private var count = 0
        let key: Int
        var body: some View { Button("\(key):\(count)") { count += 1 } }
    }

    @ViewBuilder
    private func stateful(_ kind: Kind, data: [Entry]) -> some View {
        switch kind {
        case .list: List(data, id: \.key) { StatefulRow(key: $0.key) }
        case .table: Table(data, id: \.key) { TableColumn("Row") { StatefulRow(key: $0.key) } }
        }
    }

    @Test("Nonselectable keyed rows retain state on reorder and insertion, and release removed rows")
    func keyedLifetime() throws {
        // -- Arrange --
        for kind in Kind.allCases {
            let renderer = ViewRenderer.make(stateful(kind, data: entries))
            _ = renderer.render(.now)
            _ = renderer.handle(.enter)
            _ = renderer.render(.now)
            weak var row: ViewRenderer?
            row = renderer.keyedNode(for: 1)

            // -- Act --
            renderer.update(stateful(kind, data: Array(entries.reversed())), at: .now)
            let reordered = try #require(renderer.render(.now).grid)
            let retained = row != nil && row === renderer.keyedNode(for: 1)
            _ = renderer.handle(.enter)
            renderer.update(stateful(kind, data: [Entry(key: 3, name: "Three")] + entries), at: .now)
            let inserted = try #require(renderer.render(.now).grid)
            renderer.update(stateful(kind, data: [entries[1]]), at: .now)
            _ = renderer.render(.now)

            // -- Assert --
            #expect(retained && reordered.snapshotText.contains("1:1"))
            #expect(inserted.snapshotText.contains("1:2") && inserted.snapshotText.contains("3:0"))
            #expect(row == nil)
        }
    }

    @Test("Static collection viewports scroll without selecting a row")
    func scrolling() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(List(entries, id: \.key) { Text($0.name) }.frame(height: 1))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let scrolled = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.snapshotText == "One")
        #expect(scrolled.snapshotText == "Two")
        #expect(!scrolled.isFocused(column: 0, row: 0))
    }
}
