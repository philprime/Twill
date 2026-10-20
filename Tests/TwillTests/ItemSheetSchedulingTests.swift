import Foundation
import Testing

@testable import Twill

@Suite("Payload sheet scheduling")
@MainActor
struct ItemSheetSchedulingTests {
    private struct Payload: Identifiable {
        let id: Int
        let title: String
    }

    @Test("Matching payload IDs retain phase, replacements release identity, and nil leaves the base schedule")
    func independentPhases() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var sheetDates: [Date] = []
        func content(_ item: Payload?) -> some View {
            TimelineView(.periodic(from: start, by: 20)) { _ in Text("Base") }
                .sheet(item: .constant(item)) { payload in
                    TimelineView(.periodic(from: start, by: 10)) { context in
                        sheetDates.append(context.date)
                        return Text(payload.title)
                    }
                }
        }
        let renderer = ViewRenderer.make(content(Payload(id: 1, title: "One")))
        _ = renderer.render(start)
        weak var original: ViewRenderer?
        original = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(Payload(id: 1, title: "Updated")), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = original != nil && original === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(Payload(id: 2, title: "Next")), at: start.addingTimeInterval(11))
        let replaced = renderer.render(start.addingTimeInterval(11))
        renderer.update(content(nil), at: start.addingTimeInterval(12))
        let dismissed = renderer.render(start.addingTimeInterval(12))

        // -- Assert --
        #expect(retained && original == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(replaced.nextUpdate == start.addingTimeInterval(20))
        #expect(dismissed.nextUpdate == start.addingTimeInterval(20))
        #expect(sheetDates == [start, start, start.addingTimeInterval(10), start.addingTimeInterval(11)])
    }

    @Test("Unchanged payload sheet output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Base").sheet(item: .constant(Payload(id: 1, title: "Payload"))) { Text($0.title) }
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
