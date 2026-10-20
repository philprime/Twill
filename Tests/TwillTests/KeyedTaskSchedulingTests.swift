import Foundation
import Testing

@testable import Twill

@Suite("Keyed task scheduling")
@MainActor
struct KeyedTaskSchedulingTests {
    @Test("Task IDs do not restart sibling deadlines or retain removed branches", .timeLimit(.minutes(1)))
    func independentPhases() async {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let registry = MountedTaskRegistry()
        var starts: [Int] = []
        var dates: [Date] = []
        func content(_ id: Int, show: Bool = true) -> some View {
            VStack {
                if show {
                    TimelineView(.periodic(from: start, by: 10)) { _ in Text("Work") }
                        .task(id: id) { starts.append(id) }.id("branch")
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    dates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(1), taskRegistry: registry)
        _ = renderer.render(start)
        await registry.join()
        weak var branch: ViewRenderer?
        branch = renderer.keyedNode(for: "branch")

        // -- Act --
        renderer.update(content(1), at: start.addingTimeInterval(1))
        let equal = renderer.render(start.addingTimeInterval(1))
        renderer.update(content(2), at: start.addingTimeInterval(2))
        let changed = renderer.render(start.addingTimeInterval(2))
        await registry.join()
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(2, show: false), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))
        renderer.unmount()
        await registry.join()

        // -- Assert --
        #expect(starts == [1, 2] && branch == nil)
        #expect(equal.nextUpdate == start.addingTimeInterval(10) && changed.nextUpdate == equal.nextUpdate)
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start, start])
    }

    @Test("Parent ticks and cached resize preserve equal task IDs and unchanged output", .timeLimit(.minutes(1)))
    func unchangedOutput() async throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        var starts = 0
        let started = AsyncStream<Void>.makeStream()
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Work").task(id: 1) {
                    starts += 1
                    started.continuation.yield(())
                }
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        var notifications = started.stream.makeAsyncIterator()
        _ = await notifications.next()
        let writes = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()
        let unchanged = output.writes == writes
        try host.resize(to: TerminalSize(columns: 20, rows: 5))
        host.stop()
        await host.joinTasks()

        // -- Assert --
        #expect(unchanged && starts == 1)
    }
}
