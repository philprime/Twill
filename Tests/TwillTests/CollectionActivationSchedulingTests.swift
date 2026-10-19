import Foundation
import Testing

@testable import Twill

@Suite("Collection activation scheduling")
@MainActor
struct CollectionActivationSchedulingTests {
    @Test("Callback updates retain keyed rows and independent deadlines")
    func callbackUpdates() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var rowDates: [Date] = []
        var activated: [String] = []
        func content(_ tag: String) -> some View {
            HStack {
                List([1], id: \.self, selection: .constant(nil)) { _ in
                    TimelineView(.periodic(from: start, by: 20)) { context in
                        rowDates.append(context.date)
                        return Text("Row")
                    }
                }.onActivate { activated.append("\(tag):\($0)") }
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content("Old"))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        _ = renderer.handle(.enter)
        renderer.update(content("New"), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.handle(.enter)
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(activated == ["Old:1", "New:1"])
        #expect(retained)
        #expect(rowDates == [start, start])
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    private struct RemovingList: View {
        @State private var items = [1]
        let activated: @MainActor (Int) -> Void
        var body: some View {
            List(items, id: \.self, selection: .constant(nil)) { Text("\($0)") }.onActivate {
                activated($0)
                items.removeAll()
            }
        }
    }

    @Test("Activation can remove its own rows and releases their mounted nodes")
    func removingRows() {
        // -- Arrange --
        var calls = 0
        let renderer = ViewRenderer.make(RemovingList(activated: { _ in calls += 1 }))
        _ = renderer.render(.now)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)
        let hadRow = row != nil

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(calls == 1)
        #expect(hadRow && row == nil)
    }

    @Test("Callback updates with unchanged output do not write another frame")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                List([1], id: \.self, selection: .constant(nil)) { Text("\($0)") }.onActivate { _ in }
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let writes = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == writes)
    }
}
