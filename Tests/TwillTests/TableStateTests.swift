import Foundation
import Testing

@testable import Twill

@Suite("Mounted table state")
@MainActor
struct TableStateTests {
    private struct Item: Identifiable {
        let id: Int
        let name: String
    }

    private final class Items {
        var values = [Item(id: 0, name: "A"), Item(id: 1, name: "B")]
        var increments: [Int: @MainActor () -> Void] = [:]
    }

    private struct CounterCell: View {
        @State private var count = 0
        let item: Item
        let items: Items

        var body: some View {
            let binding = $count
            items.increments[item.id] = { binding.wrappedValue += 1 }
            return Text("\(item.name)\(count)")
        }
    }

    @Test("Reordering rows retains cell state and selected identity")
    func keyedCells() throws {
        // -- Arrange --
        let items = Items()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                Table(items.values, selection: Binding(get: { 0 }, set: { _ in })) {
                    TableColumn("Value") { CounterCell(item: $0, items: items) }
                }
            })
        _ = renderer.render(start)
        let increment = try #require(items.increments[0])

        // -- Act --
        increment()
        _ = renderer.render(start)
        items.values.reverse()
        let reordered = try #require(renderer.render(start.addingTimeInterval(1)).grid)

        // -- Assert --
        #expect(reordered.snapshotText == "Value\nB0   \nA1   ")
        #expect(!reordered.isFocused(column: 0, row: 1))
        #expect(reordered.isFocused(column: 0, row: 2))
    }

    private struct StatefulTable: View {
        @State private var selection: Int? = 0

        var body: some View {
            Table((0..<5).map { Item(id: $0, name: "Row \($0)") }, selection: $selection) {
                TableColumn("Name", value: \.name)
            }.frame(height: 2)
        }
    }

    @Test("Selection writes coalesce presentation without scheduling timers")
    func coalescedPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: StatefulTable(), runLoop: runLoop, output: output)
        try host.start()
        let source = try #require(runLoop.sources.first)

        // -- Act --
        let first = host.handle(.arrowDown)
        let second = host.handle(.arrowDown)
        source.action()
        host.stop()

        // -- Assert --
        #expect(first && second)
        #expect(runLoop.timers.isEmpty)
        #expect(runLoop.signalled.count == 1)
        #expect(output.writes.count == 3)
        #expect(output.writes[1].contains("\u{1B}[7m2\u{1B}[27m"))
    }
}
