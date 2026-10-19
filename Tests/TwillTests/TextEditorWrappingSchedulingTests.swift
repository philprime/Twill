import Foundation
import Testing

@testable import Twill

@Suite("Wrapped editor scheduling")
@MainActor
struct TextEditorWrappingSchedulingTests {
    @Test("Wrapping changes preserve sibling phases and deadlines")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var text = "one two three"
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ mode: Text.LineBreakMode) -> some View {
            HStack {
                TextEditor(text: Binding(get: { text }, set: { text = $0 }), lineBreakMode: mode)
                    .frame(width: 5, height: 2)
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
        let renderer = ViewRenderer.make(content(.clipping))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(.wordWrapping), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(text == "one two three")
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    @Test("Parent updates retain wrapped viewport memory while keyed replacement resets it")
    func mountedLifetime() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { context in
                TextEditor(text: .constant("abcdef"), lineBreakMode: .characterWrapping)
                    .id(context.date < start.addingTimeInterval(2) ? 0 : 1).frame(width: 4, height: 1)
            })
        let initial = try #require(renderer.render(start).grid)

        // -- Act --
        _ = renderer.handle(.home)
        let moved = try #require(renderer.render(start).grid)
        let refreshed = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        let replaced = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(initial.snapshotText == "def ")
        #expect(moved.snapshotText == "abc ")
        #expect(refreshed == moved)
        #expect(replaced == initial)
    }

    @Test("Unchanged wrapped output is suppressed when its enclosing timeline ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                TextEditor(text: .constant("one two three"), lineBreakMode: .wordWrapping).frame(width: 5, height: 2)
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let source = try #require(loop.sources.first)
        source.action()
        let initial = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == initial)
    }
}
