import Foundation
import Testing

@testable import Twill

@Suite("Disabled content lifetimes")
@MainActor
struct DisabledSchedulingTests {
    @Test("Disabling content preserves its timeline deadline and its sibling's schedule")
    func independentSchedules() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(disabled: Bool) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("Content")
                }.disabled(disabled)
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(disabled: false))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(disabled: true), at: start.addingTimeInterval(1))
        let disabled = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(disabled.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
        #expect(ticked.grid?.snapshotText == "Content Sibling")
    }

    @Test("Disabling static content with unchanged appearance does not write another frame")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { context in
                Text("Static").disabled(context.date > start)
            },
            runLoop: runLoop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let timer = try #require(runLoop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KStatic"])
    }
}
