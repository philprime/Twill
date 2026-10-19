import Foundation
import Testing

@testable import Twill

@Suite("Control style scheduling and lifetime")
@MainActor
struct ControlStyleSchedulingTests {
    private struct Tint: ControlStyle {
        let color: Color
        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            ControlAppearance(foreground: color)
        }
    }

    @Test("Style updates preserve independent progress and timeline deadlines")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        func content(_ color: Color) -> some View {
            HStack {
                ProgressView("Loading")
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Button("Tick") {}
                }
            }.controlStyle(Tint(color: color))
        }
        let renderer = ViewRenderer.make(content(.red))
        let initial = renderer.render(start)

        // -- Act --
        renderer.update(content(.green), at: start.addingTimeInterval(0.01))
        let updated = renderer.render(start.addingTimeInterval(0.01))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(updated.nextUpdate == initial.nextUpdate)
        #expect(ticked.nextUpdate != nil)
    }

    @Test("Removing a styled control releases its weak cached owner")
    func branchRemoval() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { context in
                Group {
                    if context.date == start { Button("Owned") {} } else { Text("Gone") }
                }
            }.controlStyle(Tint(color: .red)))
        _ = renderer.render(start)
        weak var owner: ViewRenderer?
        owner = renderer.focusTarget()?.layoutState.controlOwner
        let hadOwner = owner != nil

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(hadOwner)
        #expect(owner == nil)
    }

    @Test("Unchanged styled output remains suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Button("Same") {}.controlStyle(Tint(color: .red))
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
