import Foundation
import Testing

@testable import Twill

@Suite("Shortcut scheduling")
@MainActor
struct KeyboardShortcutSchedulingTests {
    @Test("Shortcut lookup does not evaluate bodies or advance independent timeline deadlines")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        var actions = 0
        let renderer = ViewRenderer.make(
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Button("Save") { actions += 1 }.keyboardShortcut(.s)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            })
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.handle(.s)
        let frame = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(actions == 1)
        #expect(dates == [start])
        #expect(siblingDates == [start])
        #expect(frame.nextUpdate == start.addingTimeInterval(10))
    }

    @Test("A static shortcut action with unchanged output leaves the host unscheduled")
    func unchangedOutput() throws {
        // -- Arrange --
        var actions = 0
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack {
                Button("Other") {}
                Button("Save") { actions += 1 }.keyboardShortcut(.s)
            }, runLoop: runLoop, output: output)
        try host.start()
        defer { host.stop() }
        let initial = output.writes

        // -- Act --
        let handled = host.handle(.s)

        // -- Assert --
        #expect(handled && actions == 1)
        #expect(output.writes == initial)
        #expect(runLoop.timers.isEmpty)
    }
}
