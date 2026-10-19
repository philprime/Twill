import Foundation
import Testing

@testable import Twill

@Suite("Attribute presentation scheduling")
@MainActor
struct TextAttributeSchedulingTests {
    @Test("Attribute updates change cells without shifting independent child timelines")
    func inheritedUpdates() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(bold: Bool) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("First")
                }.bold(bold)
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Second")
                }
            }
        }
        let renderer = ViewRenderer.make(content(bold: false))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(bold: true), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))
        let grid = try #require(updated.grid)

        // -- Assert --
        #expect(grid.attributes(column: 0, row: 0) == [.bold])
        #expect(grid.attributes(column: 6, row: 0).isEmpty)
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    private struct Counter: View {
        @State private var count = 0
        let isBold: Bool
        var body: some View { Button("Count \(count)") { count += 1 }.bold(isBold) }
    }

    @Test("Attribute updates preserve mounted control state")
    func mountedState() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(isBold: false))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(isBold: true), at: .now)
        _ = renderer.handle(.enter)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "Count 2")
        #expect(frame.attributes(column: 0, row: 0) == [.bold])
    }

    @Test("Unchanged attributed output remains suppressed on a parent tick")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Same").bold().dim().italic().underline()
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
