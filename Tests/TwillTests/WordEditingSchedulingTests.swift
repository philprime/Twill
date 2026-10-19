import Foundation
import Testing

@testable import Twill

@Suite("Word editing scheduling")
@MainActor
struct WordEditingSchedulingTests {
    @Test("Mode updates and word navigation preserve independent sibling phases")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var text = "one two"
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(mode: TextEditingMode) -> some View {
            HStack {
                TextField("Value", text: Binding(get: { text }, set: { text = $0 }), editingMode: mode)
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
        let renderer = ViewRenderer.make(content(mode: .editable))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(mode: .readOnly), at: start.addingTimeInterval(1))
        _ = renderer.handle(.x)
        _ = renderer.handle(.arrowLeft.withModifiers(.alt))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(text == "one two")
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
        #expect(renderer.caretPosition == CellPosition(column: 4, row: 0))
    }

    @Test("Read-only mutation attempts emit no output and keep the existing timer")
    func readOnlyOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var text = "one two"
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack {
                TextField("Value", text: Binding(get: { text }, set: { text = $0 }), editingMode: .readOnly)
                TimelineView(.periodic(from: start, by: 10)) { _ in Text("Static") }
            }, runLoop: loop, output: output, now: { start })
        try host.start()
        defer { host.stop() }
        let source = try #require(loop.sources.first)
        source.action()
        let timer = try #require(loop.timers.first)
        let initial = output.writes

        // -- Act --
        for key: KeyEvent in [.x, .backspace.withModifiers(.control), .delete.withModifiers(.alt)] {
            _ = host.handle(key)
        }
        source.action()

        // -- Assert --
        #expect(text == "one two")
        #expect(output.writes == initial)
        #expect(loop.timers.count == 1 && loop.timers.first === timer)
        #expect(loop.cancelled.isEmpty)
    }
}
