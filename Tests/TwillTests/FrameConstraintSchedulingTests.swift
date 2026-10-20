import Foundation
import Testing

@testable import Twill

@Suite("Frame constraint scheduling")
@MainActor
struct FrameConstraintSchedulingTests {
    @Test("Minimum updates retain keyed rows and independent phases, removal drops owned work")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ minimum: Int, ids: [Int]) -> some View {
            HStack {
                ForEach(ids, id: \.self) { _ in
                    TimelineView(.periodic(from: start, by: 10)) { context in
                        dates.append(context.date)
                        return Text("A")
                    }
                }.frame(minWidth: minimum, maxHeight: .infinity)
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("B")
                }
            }
        }
        let renderer = ViewRenderer.make(content(3, ids: [1]))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(6, ids: [1]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(6, ids: []), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(retained && row == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start, start])
    }

    @Test("Parent ticks with unchanged mixed constraints do not write another frame")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("X").frame(width: 4, minHeight: 2, maxHeight: .infinity)
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
