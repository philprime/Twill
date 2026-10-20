import Foundation
import Testing

@testable import Twill

@Suite("Scroll indicator scheduling")
@MainActor
struct ScrollIndicatorSchedulingTests {
    @Test("Visibility updates retain keyed nodes and phase, removal drops child work")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Int: [Date]] = [:]
        func content(_ visibility: ScrollIndicatorVisibility, ids: [Int]) -> some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ids, id: \.self) { id in
                        TimelineView(.periodic(from: start, by: id == 1 ? 10 : 20)) { context in
                            dates[id, default: []].append(context.date)
                            return Text("\(id)")
                        }
                    }
                }
            }.scrollIndicators(visibility).frame(width: 3, height: 1)
        }
        let renderer = ViewRenderer.make(content(.visible, ids: [1, 2]))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 2)

        // -- Act --
        renderer.update(content(.hidden, ids: [1, 2]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 2)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(.visible, ids: [1]), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(retained && row == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates[1] == [start, start, start.addingTimeInterval(10), start.addingTimeInterval(10)])
        #expect(dates[2] == [start, start])
    }

    @Test("Unchanged indicator cells do not emit output on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                ScrollView {
                    VStack(spacing: 0) { ForEach(0..<6, id: \.self) { Text("\($0)") } }
                }.scrollIndicators(.visible).frame(width: 3, height: 3)
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
