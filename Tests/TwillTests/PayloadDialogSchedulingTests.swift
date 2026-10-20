import Foundation
import Testing

@testable import Twill

@Suite("Payload dialog scheduling")
@MainActor
struct PayloadDialogSchedulingTests {
    private struct Payload: Identifiable {
        let id: Int
        let title: String
    }

    @Test("Action labels retain phases for matching IDs and replacements release keyed content")
    func independentPhases() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var callbacks = 0
        func content(_ value: Payload?) -> some View {
            TimelineView(.periodic(from: start, by: 20)) { _ in Text("Base") }
                .alert(
                    "Notice", item: .constant(value), onDismiss: { callbacks += 1 },
                    actions: { payload in
                        Button(
                            action: {},
                            label: {
                                TimelineView(.periodic(from: start, by: 10)) { context in
                                    dates.append(context.date)
                                    return Text(payload.title)
                                }
                            })
                    })
        }
        let renderer = ViewRenderer.make(content(Payload(id: 1, title: "One")))
        _ = renderer.render(start)
        weak var old: ViewRenderer?
        old = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(Payload(id: 1, title: "Updated")), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let retained = old != nil && old === renderer.keyedNode(for: 1)
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content(Payload(id: 2, title: "Next")), at: start.addingTimeInterval(11))
        _ = renderer.render(start.addingTimeInterval(11))
        let uninterrupted = callbacks == 0
        renderer.update(content(nil), at: start.addingTimeInterval(12))
        let dismissed = renderer.render(start.addingTimeInterval(12))

        // -- Assert --
        #expect(retained && old == nil && uninterrupted)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(dismissed.nextUpdate == start.addingTimeInterval(20) && callbacks == 1)
        #expect(dates == [start, start, start.addingTimeInterval(10), start.addingTimeInterval(11)])
    }

    @Test("Unchanged payload confirmations suppress parent-tick output")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Base").confirmationDialog("Choose", item: .constant(Payload(id: 1, title: "One"))) { payload in
                    Button(payload.title) {}
                    Button("Cancel", role: .cancel) {}
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
