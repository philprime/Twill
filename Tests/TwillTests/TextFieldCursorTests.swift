import Foundation
import Testing

@testable import Twill

@Suite("Text field hardware caret")
@MainActor
struct TextFieldCursorTests {
    @Test("An editing caret on a later row is hidden before shell restoration")
    func multiRowCaretShutdown() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let host = ViewHost(rootView: MultilineCursorFixture(), runLoop: runLoop, output: output)
        try host.start()

        // -- Act --
        _ = host.handle(.enter)
        try #require(runLoop.timers.last).action()
        let shown = try #require(output.writes.last)
        host.stop()

        // -- Assert --
        #expect(shown.contains("\r\u{1B}[1B\u{1B}[2C\u{1B}[?25h"))
        #expect(output.writes.last == "\u{1B}[?25l\r\u{1B}[1A\u{1B}[1B\r\n")
    }

    @Test("Clipping the editing row hides its caret until the row is visible again")
    func clippedCaret() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let host = ViewHost(rootView: MultilineCursorFixture(), runLoop: runLoop, output: output)
        try host.start(size: TerminalSize(columns: 3, rows: 2))
        _ = host.handle(.enter)
        try #require(runLoop.timers.last).action()

        // -- Act --
        try host.resize(to: TerminalSize(columns: 3, rows: 1))
        let clipped = try #require(output.writes.last)
        try host.resize(to: TerminalSize(columns: 3, rows: 2))
        let restored = try #require(output.writes.last)
        host.stop()

        // -- Assert --
        #expect(clipped.contains("\u{1B}[?25l"))
        #expect(!clipped.contains("\u{1B}[?25h"))
        #expect(restored.contains("\r\u{1B}[1B\u{1B}[2C\u{1B}[?25h"))
    }

    @Test("An unchanged timeline tick does not rewrite a visible caret")
    func unchangedCaret() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        var evaluations = 0
        var value = "Text"
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack {
                TextField("Name", text: Binding(get: { value }, set: { value = $0 }))
                TimelineView(.periodic(from: start, by: 1)) { _ in
                    evaluations += 1
                    return Text("Static")
                }
            }, runLoop: runLoop, output: output, now: { now }
        )
        try host.start()
        let deadline = try #require(runLoop.timers.first)

        // -- Act --
        _ = host.handle(.enter)
        try #require(runLoop.timers.last).action()
        let writesBeforeTick = output.writes.count
        now = start.addingTimeInterval(1)
        try deadline.action()
        let writesAfterTick = output.writes.count
        host.stop()

        // -- Assert --
        #expect(evaluations == 2)
        #expect(writesAfterTick == writesBeforeTick)
    }

    @Test("Editing positions the cursor in display cells and Escape hides it")
    func editingCaret() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let host = ViewHost(rootView: CursorFixture(), runLoop: runLoop, output: output)
        try host.start()
        let initial = try #require(output.writes.last)

        // -- Act --
        _ = host.handle(.enter)
        try #require(runLoop.timers.last).action()
        let shown = try #require(output.writes.last)
        _ = host.handle(.arrowLeft)
        try #require(runLoop.timers.last).action()
        let moved = try #require(output.writes.last)
        _ = host.handle(.escape)
        try #require(runLoop.timers.last).action()
        let hidden = try #require(output.writes.last)
        host.stop()

        // -- Assert --
        #expect(!initial.contains("\u{1B}[?25h"))
        #expect(shown.contains("\r\u{1B}[5C\u{1B}[?25h"))
        #expect(moved.contains("\r\u{1B}[3C\u{1B}[?25h"))
        #expect(hidden.contains("\u{1B}[?25l"))
        #expect(output.writes.last == "\n")
    }
}

@MainActor
private struct MultilineCursorFixture: View {
    @State private var text = "界"

    var body: some View {
        VStack {
            Text("Top")
            TextField("Name", text: $text)
        }
    }
}

@MainActor
private struct CursorFixture: View {
    @State private var text = "A界"

    var body: some View {
        HStack(spacing: 1) {
            Text("L")
            TextField("Name", text: $text)
        }
    }
}
