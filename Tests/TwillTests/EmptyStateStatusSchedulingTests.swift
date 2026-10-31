import Foundation
import Testing

@testable import Twill

@Suite("Empty state and status scheduling")
@MainActor
struct EmptyStateStatusSchedulingTests {
    @Test("Independent label/status deadlines survive parent updates and branch removal")
    func independentPhases() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var labels: [Date] = []
        var statuses: [Date] = []
        func content(_ show: Bool, message: String) -> some View {
            VStack {
                if show {
                    ContentUnavailableView {
                        TimelineView(.periodic(from: start, by: 10)) { context in
                            labels.append(context.date)
                            return Text("Unavailable")
                        }
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {}
                    }
                    .id(1)
                }
                StatusBar {
                    TimelineView(.periodic(from: start, by: 20)) { context in
                        statuses.append(context.date)
                        return Text("Ready")
                    }
                }
            }
        }
        let renderer = ViewRenderer.make(content(true, message: "Original"))
        _ = renderer.render(start)
        weak var branch: ViewRenderer?
        branch = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(true, message: "Updated"), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = branch != nil && branch === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(false, message: "Updated"), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(retained && branch == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(labels == [start, start, start.addingTimeInterval(10)])
        #expect(statuses == [start, start, start])
    }

    @Test("Static composed output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                VStack {
                    ContentUnavailableView("Empty", description: "Try again")
                    StatusBar { Text("Ready") }
                }.frame(width: 20, height: 7)
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
