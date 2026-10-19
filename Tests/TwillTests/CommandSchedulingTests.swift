import Foundation
import Testing

@testable import Twill

@Suite("Command hint scheduling")
@MainActor
struct CommandSchedulingTests {
    @Test("Availability updates preserve independent timeline phases and deadlines")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        var actions = 0
        func content(available: Bool) -> some View {
            let command = Command(
                "save", title: "Save", isEnabled: available,
                shortcuts: [KeyboardShortcut(.controlS)]
            ) { actions += 1 }
            return HStack {
                KeyHints([command])
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("First")
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Second")
                }
            }
        }
        let renderer = ViewRenderer.make(content(available: true))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(available: false), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let key = renderer.handle(.controlS)
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
        #expect(!key && actions == 0)
    }

    @Test("Static hints add no work beyond their enclosing timeline and unchanged output is suppressed")
    func staticHints() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let command = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)]) {}
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in KeyHints([command]) },
            runLoop: runLoop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let initial = output.writes
        let timer = try #require(runLoop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == initial)
        #expect(runLoop.timers.count == 2)
    }
}
