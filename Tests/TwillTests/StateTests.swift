import Foundation
import Testing

@testable import Twill

@Suite("Mounted view state")
@MainActor
struct StateTests {
    private struct Counter: View {
        @State private var count = 0
        let captureIncrement: @MainActor (@escaping @MainActor () -> Void) -> Void

        var body: some View {
            captureIncrement { count += 1 }
            return Text("\(count)")
        }
    }

    private struct UnchangedCounter: View {
        @State private var count = 0
        let captureIncrement: @MainActor (@escaping @MainActor () -> Void) -> Void

        var body: some View {
            captureIncrement { count += 1 }
            return Text("Unchanged")
        }
    }

    @Test("State writes request one presentation for the latest value")
    func coalescedPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var increment: (@MainActor () -> Void)?
        let host = ViewHost(
            rootView: Counter { increment = $0 }, runLoop: runLoop, output: output
        )
        try host.start()

        // -- Act --
        let action = try #require(increment)
        action()
        action()
        let pendingCount = runLoop.timers.count
        try #require(runLoop.timers.last).action()
        host.stop()

        // -- Assert --
        #expect(pendingCount == 1)
        #expect(output.writes == ["\r\u{1B}[2K0", "\r2", "\n"])
    }

    @Test("State updates that do not change the frame skip output")
    func unchangedPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var increment: (@MainActor () -> Void)?
        let host = ViewHost(
            rootView: UnchangedCounter { increment = $0 }, runLoop: runLoop, output: output
        )
        try host.start()

        // -- Act --
        let action = try #require(increment)
        action()
        try #require(runLoop.timers.last).action()
        host.stop()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KUnchanged", "\n"])
    }

    @Test("Parent updates preserve a child's mounted state")
    func parentUpdate() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var increment: (@MainActor () -> Void)?
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            Counter { increment = $0 }
        }
        let renderer = ViewRenderer.make(root)
        let initial = renderer.render(start)

        // -- Act --
        let action = try #require(increment)
        action()
        let updated = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(initial.grid?.snapshotText == "0")
        #expect(updated.grid?.snapshotText == "1")
        #expect(updated.nextUpdate == start.addingTimeInterval(2))
    }

    @Test("State writes preserve a sibling's pending timeline deadline")
    func timelineIndependence() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var increment: (@MainActor () -> Void)?
        var timelineDates: [Date] = []
        let host = ViewHost(
            rootView: HStack {
                Counter { increment = $0 }
                TimelineView(.periodic(from: start, by: 1)) { context in
                    timelineDates.append(context.date)
                    return Text("T\(Int(context.date.timeIntervalSince(start)))")
                }
            },
            runLoop: runLoop, output: output, now: { now }
        )
        try host.start()
        let timelineTimer = try #require(runLoop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(0.5)
        let action = try #require(increment)
        action()
        try #require(runLoop.timers.last).action()
        let timersAfterState = runLoop.timers.count
        now = start.addingTimeInterval(1)
        timelineTimer.action()
        host.stop()

        // -- Assert --
        #expect(timersAfterState == 2)
        #expect(runLoop.cancelled.filter { $0 === timelineTimer }.isEmpty)
        #expect(timelineDates == [start, start.addingTimeInterval(1)])
        #expect(output.writes == ["\r\u{1B}[2K0 T0", "\r1", "\r\u{1B}[3C1", "\n"])
    }

    @Test("Removing a branch coalesces its pending state update with the timeline")
    func removedStateBranch() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var increment: (@MainActor () -> Void)?
        let root = TimelineView(.periodic(from: start, by: 1)) { context in
            Group {
                if context.date == start {
                    Counter { increment = $0 }
                } else {
                    Text("Gone")
                }
            }
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
        try host.start()
        let timelineTimer = try #require(runLoop.timers.first)

        // -- Act --
        let action = try #require(increment)
        action()
        now = start.addingTimeInterval(1)
        timelineTimer.action()
        host.stop()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2K0", "\rGone", "\n"])
        #expect(runLoop.cancelled.count == 2)
    }

    @Test("A nested state write refreshes a static parent")
    func nestedStateWrite() throws {
        // -- Arrange --
        var increment: (@MainActor () -> Void)?
        let renderer = ViewRenderer.make(
            HStack {
                Counter { increment = $0 }
                Text("Sibling")
            })
        let initial = renderer.render(.now)

        // -- Act --
        let action = try #require(increment)
        action()
        let updated = renderer.render(.now)

        // -- Assert --
        #expect(initial.grid?.snapshotText == "0 Sibling")
        #expect(updated.grid?.snapshotText == "1 Sibling")
        #expect(updated.nextUpdate == nil)
    }

    @Test("A state write refreshes the mounted body without remounting it")
    func stateWrite() throws {
        // -- Arrange --
        var increment: (@MainActor () -> Void)?
        let renderer = ViewRenderer.make(Counter { increment = $0 })
        let initial = renderer.render(.now)

        // -- Act --
        let action = try #require(increment)
        action()
        let updated = renderer.render(.now)

        // -- Assert --
        #expect(initial.grid?.snapshotText == "0")
        #expect(updated.grid?.snapshotText == "1")
        #expect(updated.nextUpdate == nil)
    }
}
