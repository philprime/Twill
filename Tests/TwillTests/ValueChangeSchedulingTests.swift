import Foundation
import Testing

@testable import Twill

@Suite("Value observation scheduling")
@MainActor
struct ValueChangeSchedulingTests {
    @Test("Observers preserve sibling phases and removal cancels pending work")
    func independentPhases() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var changes: [String] = []
        func content(_ show: Bool, value: Int) -> some View {
            VStack {
                if show {
                    TimelineView(.periodic(from: start, by: 10)) { _ in Text("Observed") }
                        .onChange(of: value) { changes.append("\($0):\($1)") }.id(1)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    dates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(true, value: 0))
        _ = renderer.render(start)
        weak var branch: ViewRenderer?
        branch = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(true, value: 1), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(true, value: 2), at: start.addingTimeInterval(11))
        renderer.update(content(false, value: 2), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(changes == ["0:1"] && branch == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start, start])
    }

    @Test("Equal observed values stay idle across parent ticks and cached resize")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        var changes = 0
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Static").onChange(of: 1) { _, _ in changes += 1 }
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let writes = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()
        let unchanged = output.writes == writes
        try host.resize(to: TerminalSize(columns: 20, rows: 5))

        // -- Assert --
        #expect(unchanged && changes == 0)
    }
}
