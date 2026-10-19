import Foundation
import Testing

@testable import Twill

@Suite("Nonselectable collection scheduling")
@MainActor
struct NonselectableCollectionSchedulingTests {
    @Test("Reordering display-only rows preserves their timeline phases")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Int: [Date]] = [:]
        func content(_ ids: [Int]) -> some View {
            List(ids, id: \.self) { id in
                TimelineView(.periodic(from: start, by: Double(id * 10))) { context in
                    dates[id, default: []].append(context.date)
                    return Text("\(id)")
                }
            }
        }
        let renderer = ViewRenderer.make(content([1, 2]))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content([2, 1]), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates[1] == [start, start, start.addingTimeInterval(10)])
        #expect(dates[2] == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    @Test("Unchanged display-only rows emit no output on a parent tick")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                List([1, 2], id: \.self) { Text("\($0)") }
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
