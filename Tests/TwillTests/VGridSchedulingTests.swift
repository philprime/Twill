import Foundation
import Testing

@testable import Twill

@Suite("Eager grid scheduling")
@MainActor
struct VGridSchedulingTests {
    @Test("Offscreen children keep independent deadlines and removal drops their schedules")
    func offscreenSchedules() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Int: [Date]] = [:]
        func content(_ ids: [Int]) -> some View {
            VGrid(columns: [GridItem(.fixed(2))], rowSpacing: 0) {
                ForEach(ids, id: \.self) { id in
                    TimelineView(.periodic(from: start, by: id == 1 ? 10 : 3)) { context in
                        dates[id, default: []].append(context.date)
                        return Text("\(id)")
                    }
                }
            }.frame(height: 1)
        }
        let renderer = ViewRenderer.make(content([1, 2]))
        let first = renderer.render(start)
        weak var offscreen: ViewRenderer?
        offscreen = renderer.keyedNode(for: 2)
        let existed = offscreen != nil

        // -- Act --
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 8)))
        renderer.update(content([1]), at: start.addingTimeInterval(1))
        let removed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(existed && offscreen == nil)
        #expect(first.nextUpdate == start.addingTimeInterval(3))
        #expect(removed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
        #expect(resized.snapshotText == "1 ")
        #expect(dates[1] == [start, start, start.addingTimeInterval(10)])
        #expect(dates[2] == [start])
    }

    @Test("Unchanged eager grid output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                VGrid(columns: [GridItem(.fixed(2))]) {
                    Text("A")
                    Text("B")
                }
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
