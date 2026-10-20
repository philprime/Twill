import Foundation
import Testing

@testable import Twill

@Suite("Nested menu scheduling")
@MainActor
struct NestedMenuSchedulingTests {
    @Test("Child menus retain parent label phases and dismissal removes only child schedules")
    func parentPhases() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var parentDates: [Date] = []
        var childDates: [Date] = []
        let renderer = ViewRenderer.make(
            Menu("Root") {
                Button(
                    action: {},
                    label: {
                        TimelineView(.periodic(from: start, by: 10)) { context in
                            parentDates.append(context.date)
                            return Text("Parent")
                        }
                    })
                Menu("More") {
                    ForEach([1], id: \.self) { _ in
                        Button(
                            action: {},
                            label: {
                                TimelineView(.periodic(from: start, by: 20)) { context in
                                    childDates.append(context.date)
                                    return Text("Child")
                                }
                            })
                    }
                }
            })
        _ = renderer.render(start)
        _ = renderer.handle(.enter)
        _ = renderer.render(start)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let opened = renderer.render(start)
        weak var child: ViewRenderer?
        child = renderer.keyedNode(for: 1)

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(10))
        _ = renderer.handle(.escape)
        let returned = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(opened.nextUpdate == start.addingTimeInterval(10))
        #expect(returned.nextUpdate == start.addingTimeInterval(20))
        #expect(parentDates == [start, start.addingTimeInterval(10)])
        #expect(childDates == [start] && child == nil)
    }

    @Test("Unchanged nested menus suppress output on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Menu("Root") { Menu("More") { Button("Leaf") {} } }
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        _ = host.handle(.enter)
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
}
