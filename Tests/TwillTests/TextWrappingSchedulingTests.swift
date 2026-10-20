import Foundation
import Testing

@testable import Twill

@Suite("Text reflow scheduling")
@MainActor
struct TextWrappingSchedulingTests {
    @Test("Break-mode updates preserve independent child phases and deadlines")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(mode: Text.LineBreakMode) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("one two three").lineBreakMode(mode).frame(width: 5)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(mode: .wordWrapping))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(mode: .clipping), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    @Test("A removed wrapped branch leaves its sibling's deadline unchanged")
    func removedBranch() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        func content(visible: Bool) -> some View {
            VStack {
                if visible {
                    TimelineView(.periodic(from: start, by: 10)) { _ in Text("one two three").lineLimit(2) }
                }
                TimelineView(.periodic(from: start, by: 20)) { _ in Text("Sibling") }
            }
        }
        let renderer = ViewRenderer.make(content(visible: true))
        _ = renderer.render(start, proposal: .init(width: 5))

        // -- Act --
        renderer.update(content(visible: false), at: start.addingTimeInterval(1))
        let frame = renderer.render(start.addingTimeInterval(1), proposal: .init(width: 5))

        // -- Assert --
        #expect(frame.nextUpdate == start.addingTimeInterval(20))
    }

    @Test("Unchanged wrapped output is suppressed when a parent timeline ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in Text("one two three").frame(width: 5) },
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
    }
}
