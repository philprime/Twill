import Foundation
import Testing

@testable import Twill

@Suite("Split pane scheduling")
@MainActor
struct SplitViewSchedulingTests {
    @Test("Pane-width updates retain keyed timelines and removal releases mounted rows")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ width: Int, ids: [Int]) -> some View {
            SplitView(leadingWidth: .fixed(width)) {
                ForEach(ids, id: \.self) { _ in
                    TimelineView(.periodic(from: start, by: 10)) { context in
                        dates.append(context.date)
                        return Text("L")
                    }
                }
            } trailing: {
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("R")
                }
            }.frame(width: 12)
        }
        let renderer = ViewRenderer.make(content(3, ids: [1]))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(5, ids: [1]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(5, ids: []), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(retained && row == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start, start])
    }

    @Test("Unchanged split panes emit no output on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                SplitView(leadingWidth: .fixed(3)) {
                    Text("L")
                } trailing: {
                    Text("R")
                }.frame(width: 12, height: 2)
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
