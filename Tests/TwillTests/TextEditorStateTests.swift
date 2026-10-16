import Foundation
import Testing

@testable import Twill

@Suite("Mounted text editor state")
@MainActor
struct TextEditorStateTests {
    private struct EditorFixture: View {
        @State private var text = "first"

        var body: some View {
            TextEditor(text: $text).frame(width: 8, height: 2)
        }
    }

    @Test("Text and caret writes coalesce without introducing timers or shifting sibling deadlines")
    func stateInvalidation() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: VStack {
                EditorFixture()
                TimelineView(.periodic(from: start, by: 5)) { _ in Text("Clock") }
            }, runLoop: runLoop, output: output, now: { start })
        try host.start()
        let source = try #require(runLoop.sources.first)
        let deadline = try #require(runLoop.timers.first)

        // -- Act --
        _ = host.handle(.enter)
        _ = host.handle(.a)
        _ = host.handle(.b)
        source.action()
        let unchangedDeadline = runLoop.timers.first === deadline
        host.stop()

        // -- Assert --
        #expect(runLoop.signalled.count == 1)
        #expect(runLoop.timers.count == 1)
        #expect(unchangedDeadline)
        #expect(output.writes.contains { $0.contains("ab") })
    }

    @Test("Parent reevaluation preserves the insertion point in the mounted editor")
    func parentUpdate() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var text = "abc\ndef"
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                TextEditor(text: Binding(get: { text }, set: { text = $0 }))
            })
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(text == "abcx\ndef")
    }

    @Test("External text replacements clamp the caret and scroll offset to the current value")
    func externalReplacement() throws {
        // -- Arrange --
        var text = "abc\ndef\nghijkl"
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 3, height: 1))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)

        // -- Act --
        text = "x"
        _ = renderer.handle(.end)
        let clamped = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.a)

        // -- Assert --
        #expect(clamped.snapshotText == "x  ")
        #expect(renderer.caretPosition == CellPosition(column: 1, row: 0))
        #expect(text == "xa")
    }
}
