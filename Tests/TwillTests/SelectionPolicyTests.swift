import Foundation
import Testing

@testable import Twill

@Suite("Explicit collection selection policies")
@MainActor
struct SelectionPolicyTests {
    private enum Kind: CaseIterable { case list, table, outline }
    private struct Row: Identifiable {
        let id: Int
        var children: [Row]?
    }
    private let rows = [Row(id: 1), Row(id: 3)]

    @ViewBuilder
    private func collection(_ kind: Kind, rows: [Row], selection: Binding<Int?>, policy: SelectionPolicy) -> some View {
        switch kind {
        case .list:
            List(rows, selection: selection, selectionPolicy: policy) { Text("\($0.id)") }
        case .table:
            Table(rows, selection: selection, selectionPolicy: policy) { TableColumn("ID") { Text("\($0.id)") } }
        case .outline:
            OutlineGroup(
                rows, children: \.children, selection: selection, expandedIDs: .constant([]),
                selectionPolicy: policy
            ) { Text("\($0.id)") }
        }
    }

    private func hasHighlight(_ grid: CellGrid?) -> Bool {
        guard let grid else { return false }
        return (0..<grid.size.height).contains { row in
            (0..<grid.size.width).contains { grid.isFocused(column: $0, row: row) }
        }
    }

    @Test("Nil, missing, valid and empty cases share policy semantics without render writes")
    func rendering() {
        // -- Arrange --
        for kind in Kind.allCases {
            for policy in [SelectionPolicy.firstVisible, .allowEmpty] {
                for selected in [Int?.none, 99, 3] {
                    var writes = 0
                    let binding = Binding(get: { selected }, set: { _ in writes += 1 })
                    let renderer = ViewRenderer.make(collection(kind, rows: rows, selection: binding, policy: policy))
                    let empty = ViewRenderer.make(collection(kind, rows: [], selection: binding, policy: policy))

                    // -- Act --
                    let grid = renderer.render(.now).grid
                    let emptyGrid = empty.render(.now).grid

                    // -- Assert --
                    #expect(hasHighlight(grid) == (selected == 3 || policy == .firstVisible))
                    #expect(!hasHighlight(emptyGrid))
                    #expect(writes == 0)
                }
            }
        }
    }

    @Test("Allow-empty Enter does not submit while navigation starts at the requested edge")
    func navigationFromNone() {
        // -- Arrange --
        for kind in Kind.allCases {
            for key: KeyEvent in [.arrowDown, .home, .arrowUp, .end] {
                var selection: Int?
                var submits = 0
                let renderer = ViewRenderer.make(
                    collection(
                        kind, rows: rows, selection: Binding(get: { selection }, set: { selection = $0 }),
                        policy: .allowEmpty
                    ).onSubmit { submits += 1 })
                _ = renderer.render(.now)

                // -- Act --
                let entered = renderer.handle(.enter)
                let before = selection
                let moved = renderer.handle(key)

                // -- Assert --
                #expect(entered && moved)
                #expect(submits == 0 && before == nil)
                #expect(selection == (key == .arrowDown || key == .home ? 1 : 3))
            }
        }
    }

    @Test("Outline hidden IDs resolve against visible rows and reappear without writes")
    func hiddenSelection() throws {
        // -- Arrange --
        let tree = [Row(id: 1, children: [Row(id: 2)]), Row(id: 3)]
        var expanded: Set<Int> = []
        var writes = 0
        let binding = Binding<Int?>(get: { 2 }, set: { _ in writes += 1 })
        func outline() -> some View {
            OutlineGroup(
                tree, children: \.children, selection: binding,
                expandedIDs: Binding(get: { expanded }, set: { expanded = $0 }), selectionPolicy: .allowEmpty
            ) {
                Text("\($0.id)")
            }
        }
        let renderer = ViewRenderer.make(outline())
        let hidden = renderer.render(.now).grid
        let effective = SelectionPolicy.allowEmpty.resolve(
            in: tree, selection: 2, children: \.children, expandedIDs: [])

        // -- Act --
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowLeft)
        let unchanged = expanded
        expanded = [1]
        renderer.update(outline(), at: .now)
        let visible = try #require(renderer.render(.now).grid)
        let restored = SelectionPolicy.allowEmpty.resolve(
            in: tree, selection: 2, children: \.children, expandedIDs: [1])

        // -- Assert --
        #expect(!hasHighlight(hidden) && effective == nil)
        #expect(unchanged.isEmpty)
        #expect(hasHighlight(visible) && restored?.id == 2)
        #expect(writes == 0)
    }

    @Test("Policy changes retain keyed rows and stale IDs can become selected again")
    func policyAndDataUpdates() throws {
        // -- Arrange --
        var selection: Int? = 99
        var writes = 0
        let binding = Binding(
            get: { selection },
            set: {
                selection = $0
                writes += 1
            })
        let renderer = ViewRenderer.make(collection(.list, rows: rows, selection: binding, policy: .firstVisible))
        _ = renderer.render(.now)
        weak var retainedRow: ViewRenderer?
        retainedRow = renderer.keyedNode(for: 3)

        // -- Act --
        renderer.update(collection(.list, rows: rows, selection: binding, policy: .allowEmpty), at: .now)
        let emptySelection = renderer.render(.now).grid
        let retained = retainedRow === renderer.keyedNode(for: 3)
        selection = 3
        renderer.update(collection(.list, rows: [Row(id: 1)], selection: binding, policy: .allowEmpty), at: .now)
        let filtered = renderer.render(.now).grid
        renderer.update(collection(.list, rows: rows, selection: binding, policy: .allowEmpty), at: .now)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(!hasHighlight(emptySelection) && !hasHighlight(filtered))
        #expect(retained && retainedRow == nil)
        #expect(hasHighlight(restored) && selection == 3)
        #expect(writes == 0)
    }

    @Test("Allow-empty table rows retain sortable header routing")
    func sortableHeaders() {
        // -- Arrange --
        var selection: Int?
        var order: [KeyPathComparator<Row>] = []
        var submits = 0
        func table() -> some View {
            Table(
                rows, selection: Binding(get: { selection }, set: { selection = $0 }), selectionPolicy: .allowEmpty,
                sortOrder: Binding(get: { order }, set: { order = $0 })
            ) {
                TableColumn("ID", value: \.id) { Text("\($0.id)") }
            }.onSubmit { submits += 1 }
        }
        let renderer = ViewRenderer.make(table())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let noSelection = selection
        _ = renderer.handle(.arrowUp)
        let last = selection
        renderer.update(table(), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowUp)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(noSelection == nil && last == 3)
        #expect(selection == 1 && order.count == 1)
        #expect(submits == 0)
    }

    @Test("Public resolver returns elements from the same effective selection including slices")
    func resolver() {
        // -- Arrange --
        let slice = [Row(id: 99), Row(id: 1), Row(id: 3)].dropFirst()

        // -- Act --
        let fallback = SelectionPolicy.firstVisible.resolve(in: slice, selection: 99)
        let absent = SelectionPolicy.allowEmpty.resolve(in: slice, selection: 99)
        let selected = SelectionPolicy.allowEmpty.resolve(in: slice, selection: 3, id: \.id)
        let empty = SelectionPolicy.firstVisible.resolve(in: [Row](), selection: 3)

        // -- Assert --
        #expect(fallback?.id == 1)
        #expect(absent == nil && empty == nil)
        #expect(selected?.id == 3)
    }
}
