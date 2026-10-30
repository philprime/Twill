import Foundation
import Testing

@testable import Twill

@Suite("Text alignment scheduling")
@MainActor
struct MultilineTextAlignmentSchedulingTests {
    @Test("Alignment changes preserve sibling phases and unchanged output remains suppressed")
    func alignmentUpdates() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(alignment: HorizontalAlignment) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("abcd\nx").multilineTextAlignment(alignment)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(alignment: .leading))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(alignment: .trailing), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
        #expect(changed.grid == ticked.grid)
    }

    @Test("An unchanged aligned frame adds no terminal writes on a timeline tick")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("abcd\nx").multilineTextAlignment(.center)
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let initial = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == initial)
    }
}
