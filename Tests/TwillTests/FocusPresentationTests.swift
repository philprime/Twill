import Foundation
import Testing

@testable import Twill

@Suite("Visible focus presentation")
@MainActor
struct FocusPresentationTests {
    @Test("Arrow movement updates the indicator without scheduling static content on no-op keys")
    func arrowPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack(spacing: 1) {
                Text("A").focusable()
                Text("B").focusable()
            }, runLoop: runLoop, output: output
        )
        try host.start()

        // -- Act --
        let moved = host.handle(.arrowRight)
        let pending = runLoop.timers.count
        try #require(runLoop.timers.last).action()
        let tabHandled = host.handle(.tab)
        let boundaryHandled = host.handle(.arrowRight)
        host.stop()

        // -- Assert --
        #expect(moved)
        #expect(pending == 1)
        #expect(!tabHandled)
        #expect(!boundaryHandled)
        #expect(runLoop.timers.count == 1)
        #expect(
            output.writes == [
                "\r\u{1B}[2K\u{1B}[7mA\u{1B}[27m B",
                "\rA\r\u{1B}[2C\u{1B}[7mB\u{1B}[27m",
                "\n",
            ])
    }

    @Test("Focus redraw leaves an independent timeline deadline unchanged")
    func preservesTimeline() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var evaluations = 0
        let host = ViewHost(
            rootView: HStack(spacing: 1) {
                Text("A").focusable()
                Text("B").focusable()
                TimelineView(.periodic(from: start, by: 1)) { _ in
                    evaluations += 1
                    return Text("Clock")
                }
            }, runLoop: runLoop, output: output, now: { start }
        )
        try host.start()
        let deadline = try #require(runLoop.timers.first)

        // -- Act --
        let moved = host.handle(.arrowRight)
        try #require(runLoop.timers.last).action()

        // -- Assert --
        #expect(moved)
        #expect(evaluations == 1)
        #expect(runLoop.timers.count == 2)
        #expect(!deadline.isCancelled)
        #expect(runLoop.cancelled.isEmpty)
        #expect(output.writes.count == 2)
        host.stop()
    }

    @Test("Removing the focused branch highlights the first remaining control")
    func removedFocus() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var visible = true
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            HStack(spacing: 1) {
                if visible { Text("First").focusable() }
                Text("Second").focusable()
            }
        }
        let renderer = ViewRenderer.make(root)
        let initial = try #require(renderer.render(start).grid)

        // -- Act --
        visible = false
        let remaining = try #require(renderer.render(start.addingTimeInterval(1)).grid)

        // -- Assert --
        #expect(initial.isFocused(column: 0, row: 0))
        #expect(!initial.isFocused(column: 6, row: 0))
        #expect(remaining.snapshotText == "Second")
        #expect(remaining.isFocused(column: 0, row: 0))
        #expect(InlineFrameEncoder.encode(remaining, previous: initial).contains("\u{1B}[7mSecond\u{1B}[27m"))
    }

    @Test("A focused wide glyph owns both of its styled cells")
    func wideGlyph() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 1) {
                Text("界").focusable()
                Text("A").focusable()
            })

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.isFocused(column: 0, row: 0))
        #expect(frame.isFocused(column: 1, row: 0))
        #expect(!frame.isFocused(column: 2, row: 0))
        #expect(InlineFrameEncoder.encode(frame, previous: nil) == "\r\u{1B}[2K\u{1B}[7m界\u{1B}[27m A")
    }
}
