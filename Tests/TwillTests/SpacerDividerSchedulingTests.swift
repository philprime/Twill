import Foundation
import Testing

@testable import Twill

@Suite("Spacer and Divider scheduling")
@MainActor
struct SpacerDividerSchedulingTests {
    @Test("Spacing updates retain keyed schedules and branch removal drops owned work")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ minimum: Int, ids: [Int]) -> some View {
            HStack(spacing: 0) {
                ForEach(ids, id: \.self) { _ in
                    TimelineView(.periodic(from: start, by: 10)) { context in
                        dates.append(context.date)
                        return Text("A")
                    }
                }
                Spacer(minLength: minimum)
                Divider()
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("B")
                }
            }.frame(width: 12)
        }
        let renderer = ViewRenderer.make(content(1, ids: [1]))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(3, ids: [1]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(3, ids: []), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(retained && row == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start, start])
    }

    @Test("Unchanged space and divider output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                HStack(spacing: 0) {
                    Text("A")
                    Spacer()
                    Divider()
                    Text("B")
                }.frame(width: 12)
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
