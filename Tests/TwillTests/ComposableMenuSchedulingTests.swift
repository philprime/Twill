import Foundation
import Testing

@testable import Twill

@Suite("Composable menu scheduling")
@MainActor
struct ComposableMenuSchedulingTests {
    @Test("Open keyed actions retain independent label timelines and dismissal removes their schedules")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Int: [Date]] = [:]
        func content(_ values: [Int]) -> some View {
            Menu("Actions") {
                ForEach(values, id: \.self) { id in
                    Button(
                        action: {},
                        label: {
                            TimelineView(.periodic(from: start, by: id == 0 ? 10 : 20)) { context in
                                dates[id, default: []].append(context.date)
                                return Text("\(id)")
                            }
                        })
                }
            }
        }
        let renderer = ViewRenderer.make(content([0, 1]))
        let closed = renderer.render(start)
        _ = renderer.handle(.enter)
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content([1, 0]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content([0]), at: start.addingTimeInterval(11))
        _ = renderer.render(start.addingTimeInterval(11))
        _ = renderer.handle(.escape)
        let dismissed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(closed.nextUpdate == nil)
        #expect(retained && row == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(dismissed.nextUpdate == nil)
        #expect(dates[0] == [start, start, start.addingTimeInterval(10), start.addingTimeInterval(10)])
        #expect(dates[1] == [start, start])
    }

    @Test("Unchanged open builder menus emit no output on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Menu("Actions") { Button("Run") {}.keyboardShortcut(.r) }
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        _ = host.handle(.enter)
        now = start.addingTimeInterval(1)
        try #require(loop.timers.last).action()
        let writes = output.writes
        let timer = try #require(loop.timers.last)

        // -- Act --
        now = start.addingTimeInterval(2)
        timer.action()

        // -- Assert --
        #expect(output.writes == writes)
    }

    @Test("Mounted activation callbacks cannot retain their button owner")
    func weakButtonOwner() {
        // -- Arrange --
        var renderer: ViewRenderer? = ViewRenderer.make(Menu("Actions") { Button("Run") {} })
        weak var owner: ViewRenderer?
        owner = renderer
        _ = renderer?.render(.now)
        _ = renderer?.handle(.enter)
        _ = renderer?.render(.now)

        // -- Act --
        renderer?.unmount()
        renderer = nil

        // -- Assert --
        #expect(owner == nil)
    }
}
