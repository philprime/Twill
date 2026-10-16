import Foundation
import Testing

@testable import Twill

@Suite("Selectable lists")
@MainActor
struct ListTests {
    private struct Item: Identifiable {
        let id: Int
    }

    private final class Items {
        var values = [0, 1, 2, 3]
    }

    @Test("Navigation selects stable IDs, clamps at boundaries, and submits the effective selection")
    func navigationAndActivation() throws {
        // -- Arrange --
        var selection: Int? = 20
        var activations: [Int?] = []
        let renderer = ViewRenderer.make(
            List([10, 20, 30], id: \.self, selection: Binding(get: { selection }, set: { selection = $0 })) {
                Text("Row \($0)")
            }
            .onSubmit { activations.append(selection) })
        _ = renderer.render(.now)

        // -- Act --
        let down = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let boundary = renderer.handle(.arrowDown)
        let activated = renderer.handle(.enter)
        let lastSelection = selection
        _ = renderer.handle(.home)
        _ = renderer.render(.now)
        let firstSelection = selection
        _ = renderer.handle(.end)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)

        // -- Assert --
        #expect(down && boundary && activated)
        #expect(lastSelection == 30)
        #expect(activations == [30])
        #expect(firstSelection == 10)
        #expect(selection == 20)
    }

    @Test("Absent selections fall back visually without rewriting the binding")
    func fallbackAndEmpty() throws {
        // -- Arrange --
        var selection: Int? = 99
        var submitted = false
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let renderer = ViewRenderer.make(List([Item(id: 10), Item(id: 20)], selection: binding) { Text("\($0.id)") })
        let empty = ViewRenderer.make(
            List([Item](), selection: binding) { Text("\($0.id)") }
                .onSubmit { submitted = true })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        let stored = selection
        _ = renderer.handle(.arrowDown)
        _ = empty.render(.now)
        let down = empty.handle(.arrowDown)
        _ = empty.handle(.enter)

        // -- Assert --
        #expect(grid.isFocused(column: 0, row: 0))
        #expect(!grid.isFocused(column: 0, row: 1))
        #expect(stored == 99)
        #expect(selection == 20)
        #expect(down)
        #expect(!submitted)
    }

    @Test("Selection is revealed on initial mount, navigation, and external changes")
    func automaticReveal() throws {
        // -- Arrange --
        var selection: Int? = 3
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                List(0..<6, id: \.self, selection: Binding(get: { selection }, set: { selection = $0 })) {
                    Text("Row \($0)")
                }.frame(height: 2)
            })
        let initial = try #require(renderer.render(start).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let moved = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        selection = 0
        let external = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(initial.snapshotText == "Row 2\nRow 3")
        #expect(moved.snapshotText == "Row 3\nRow 4")
        #expect(external.snapshotText == "Row 0\nRow 1")
    }

    @Test("Reordering a selected multiline row reveals its new bounds without changing its ID")
    func reorderReveal() throws {
        // -- Arrange --
        let items = Items()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                List(items.values, id: \.self, selection: Binding(get: { 0 }, set: { _ in })) { value in
                    VStack(spacing: 0) {
                        Text("Row \(value)")
                        Text("Sub \(value)")
                    }
                }.frame(height: 2)
            })
        _ = renderer.render(start)

        // -- Act --
        items.values = [1, 2, 3, 0]
        let moved = try #require(renderer.render(start.addingTimeInterval(1)).grid)

        // -- Assert --
        #expect(moved.snapshotText == "Row 0\nSub 0")
    }

    @Test("Selection survives filtering and empty collections without submitting stale IDs")
    func selectionLifetime() throws {
        // -- Arrange --
        let items = Items()
        items.values = [0, 1, 2]
        var selection: Int? = 2
        var activated: [Int?] = []
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                List(items.values, id: \.self, selection: Binding(get: { selection }, set: { selection = $0 })) {
                    Text("Row \($0)")
                }
                .onSubmit { activated.append(selection) }
            })
        _ = renderer.render(start)

        // -- Act --
        items.values = [0, 1]
        let filtered = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        let retained = selection
        items.values = []
        _ = renderer.render(start.addingTimeInterval(2))
        _ = renderer.handle(.enter)
        items.values = [1, 2]
        let restored = try #require(renderer.render(start.addingTimeInterval(3)).grid)
        _ = renderer.handle(.enter)
        selection = nil
        _ = renderer.render(start.addingTimeInterval(4))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(filtered.isFocused(column: 0, row: 0))
        #expect(retained == 2)
        #expect(restored.isFocused(column: 0, row: 1))
        #expect(activated == [2, 1])
        #expect(selection == 1)
    }

    @Test("Shrinking a viewport keeps the selected row visible")
    func resizeReveal() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            List(0..<6, id: \.self, selection: Binding(get: { 3 }, set: { _ in })) { Text("Row \($0)") })
        _ = renderer.render(.now, proposal: ProposedCellSize(height: 4))

        // -- Act --
        let smaller = try #require(renderer.drawFrame(proposal: ProposedCellSize(height: 2)))

        // -- Assert --
        #expect(smaller.snapshotText == "Row 2\nRow 3")
    }

}

extension ListTests {
    private struct ClearableList: View {
        @FocusState private var focus = true
        let captureClear: @MainActor (@escaping @MainActor () -> Void) -> Void

        var body: some View {
            let binding = $focus
            captureClear { binding.wrappedValue = false }
            return List(0..<2, id: \.self, selection: Binding(get: { 1 }, set: { _ in })) { Text("Row \($0)") }
                .focused($focus)
        }
    }

    @Test("Clearing keyboard focus does not hide selection")
    func selectionWithoutFocus() throws {
        // -- Arrange --
        var clear: (@MainActor () -> Void)?
        let renderer = ViewRenderer.make(ClearableList { clear = $0 })
        _ = renderer.render(.now)
        let clearFocus = try #require(clear)

        // -- Act --
        clearFocus()
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(renderer.focusTarget() == nil)
        #expect(grid.isFocused(column: 0, row: 1))
        #expect(!grid.isFocused(column: 0, row: 0))
    }

    @Test("Row content cannot receive keys instead of the list's enclosing handler", arguments: [1, 2])
    func rowKeyIsolation(count: Int) {
        // -- Arrange --
        var rowKeys = 0
        var listKeys = 0
        let renderer = ViewRenderer.make(
            List(0..<count, id: \.self, selection: Binding(get: { 0 }, set: { _ in })) { value in
                Text("Row \(value)").onKeyPress { _ in
                    rowKeys += 1
                    return .handled
                }
            }
            .onKeyPress { _ in
                listKeys += 1
                return .handled
            })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.d)

        // -- Assert --
        #expect(handled)
        #expect(rowKeys == 0)
        #expect(listKeys == 1)
    }

    private struct StatefulList: View {
        @State private var selection: Int? = 0

        var body: some View {
            List(0..<5, id: \.self, selection: $selection) { Text("Row \($0)") }.frame(height: 2)
        }
    }

    @Test("Mounted selection writes coalesce presentation without scheduling timers")
    func stateInvalidation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: StatefulList(), runLoop: runLoop, output: output)
        try host.start()
        let source = try #require(runLoop.sources.first)

        // -- Act --
        let down = host.handle(.arrowDown)
        let secondDown = host.handle(.arrowDown)
        source.action()
        host.stop()

        // -- Assert --
        #expect(down && secondDown)
        #expect(runLoop.signalled.count == 1)
        #expect(runLoop.timers.isEmpty)
        #expect(output.writes.contains { $0.contains("Row 2") })
    }

    private struct StatefulRow: View {
        let id: Int
        @State private var count = 0
        let capture: @MainActor (Int, @escaping @MainActor () -> Void) -> Void

        var body: some View {
            let binding = $count
            capture(id) { binding.wrappedValue += 1 }
            return Text("\(id):\(count)")
        }
    }

    @Test("Keyed rows retain mounted state after reordering and release it after removal")
    func keyedRowState() throws {
        // -- Arrange --
        let items = Items()
        var increments: [Int: @MainActor () -> Void] = [:]
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                List(items.values, id: \.self, selection: Binding(get: { 0 }, set: { _ in })) { value in
                    StatefulRow(id: value) { increments[$0] = $1 }
                }
            })
        _ = renderer.render(start)
        let increment = try #require(increments[0])

        // -- Act --
        increment()
        items.values = [1, 0]
        let reordered = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        items.values = [1]
        _ = renderer.render(start.addingTimeInterval(2))
        items.values = [0, 1]
        let remounted = try #require(renderer.render(start.addingTimeInterval(3)).grid)

        // -- Assert --
        #expect(reordered.snapshotText == "1:0\n0:1")
        #expect(remounted.snapshotText == "0:0\n1:0")
    }

    @Test("Pane switching preserves selection and routes shortcuts only through the active list")
    func paneIndependence() throws {
        // -- Arrange --
        var left: Int? = 1
        var right: Int? = 0
        var shortcuts = 0
        let renderer = ViewRenderer.make(
            HStack {
                List(0..<4, id: \.self, selection: Binding(get: { left }, set: { left = $0 })) { Text("L\($0)") }
                    .frame(height: 2)
                    .onKeyPress { key in
                        guard key == .d else { return .ignored }
                        shortcuts += 1
                        return .handled
                    }
                List(0..<4, id: \.self, selection: Binding(get: { right }, set: { right = $0 })) { Text("R\($0)") }
                    .frame(height: 2)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let switched = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let ignored = renderer.handle(.d)
        _ = renderer.handle(.shiftTab)
        let handled = renderer.handle(.d)

        // -- Assert --
        #expect(switched)
        #expect(left == 2)
        #expect(right == 1)
        #expect(!ignored && handled)
        #expect(shortcuts == 1)
    }
}
