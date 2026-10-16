import Foundation
import Testing

@testable import Twill

@Suite("Progress view scheduling")
@MainActor
struct ProgressViewSchedulingTests {
    @Test("An unlabeled spinner advances only when its deadline is delivered")
    func spinner() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(ProgressView())

        // -- Act --
        let first = renderer.render(start)
        let early = renderer.render(start.addingTimeInterval(0.05))
        let next = renderer.render(start.addingTimeInterval(0.1))
        let delayed = renderer.render(start.addingTimeInterval(0.35))

        // -- Assert --
        #expect(first.grid?.snapshotText == "|")
        #expect(first.grid?.size == CellSize(width: 1, height: 1))
        #expect(first.nextUpdate == start.addingTimeInterval(0.1))
        #expect(early.grid?.snapshotText == "|")
        #expect(early.nextUpdate == first.nextUpdate)
        #expect(next.grid?.snapshotText == "/")
        #expect(delayed.grid?.snapshotText == "\\")
        #expect(delayed.nextUpdate == start.addingTimeInterval(0.4))
    }

    @Test("Indeterminate initializers place optional labels beside the spinner")
    func labels() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let title = ViewRenderer.make(ProgressView("Loading"))
        let custom = ViewRenderer.make(ProgressView { Text("Files") })
        let nilValue = ViewRenderer.make(ProgressView("Waiting", value: nil, total: 0))

        // -- Act --
        let titleFrame = title.render(start)
        let customFrame = custom.render(start)
        let nilFrame = nilValue.render(start)

        // -- Assert --
        #expect(titleFrame.grid?.snapshotText == "| Loading")
        #expect(customFrame.grid?.snapshotText == "| Files")
        #expect(nilFrame.grid?.snapshotText == "| Waiting")
        #expect(nilFrame.nextUpdate == start.addingTimeInterval(0.1))
    }

    @Test("Parent label updates do not advance or postpone the spinner")
    func parentUpdate() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 0.05)) { context in
            ProgressView(context.date == start ? "First" : "Next")
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)

        // -- Act --
        let parent = renderer.render(start.addingTimeInterval(0.05))
        let due = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(parent.grid?.snapshotText == "| Next")
        #expect(due.grid?.snapshotText == "/ Next")
    }

    @Test("Switching to determinate progress removes animation deadlines")
    func determinateTransition() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 1)) { context in
            ProgressView(value: context.date == start ? nil : 1)
        }
        let renderer = ViewRenderer.make(root)
        let initial = renderer.render(start)

        // -- Act --
        let completed = renderer.render(start.addingTimeInterval(1), proposal: .init(width: 4, height: 1))

        // -- Assert --
        #expect(initial.nextUpdate == start.addingTimeInterval(0.1))
        #expect(completed.grid?.snapshotText == "━━━━")
        #expect(completed.nextUpdate == start.addingTimeInterval(2))
    }

    @Test("Removing a spinner leaves only the parent's deadline")
    func removal() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 1)) { context in
            HStack {
                if context.date == start { ProgressView() }
                Text("Static")
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)

        // -- Act --
        let removed = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(removed.grid?.snapshotText == "Static")
        #expect(removed.nextUpdate == start.addingTimeInterval(2))
    }

    @Test("Spinner ticks leave slow siblings cached and unchanged output unwritten")
    func hostScheduling() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        var siblingEvaluations = 0
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let root = HStack {
            ProgressView()
            TimelineView(.periodic(from: start, by: 1)) { _ -> Text in
                siblingEvaluations += 1
                return Text("Slow")
            }
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
        try host.start()

        // -- Act --
        now = start.addingTimeInterval(0.4)
        try #require(runLoop.timers.last).action()
        let writesAfterFullCycle = output.writes.count
        now = start.addingTimeInterval(0.5)
        try #require(runLoop.timers.last).action()
        let writesAfterChange = output.writes.count
        host.stop()

        // -- Assert --
        #expect(siblingEvaluations == 1)
        #expect(writesAfterFullCycle == 1)
        #expect(writesAfterChange == 2)
        #expect(runLoop.timers.count == 3)
    }
}
