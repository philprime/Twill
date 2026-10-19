import Foundation
import Testing

@testable import Twill

@Suite("Theme presentation scheduling")
@MainActor
struct ThemeSchedulingTests {
    @Test("Palette changes redraw semantic cells without shifting independent schedules")
    func independentDeadlines() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ theme: Theme) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("First").foregroundStyle(.accent)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Second")
                }
            }.theme(theme)
        }
        let renderer = ViewRenderer.make(content(Theme(accent: .red)))
        let original = renderer.render(start)

        // -- Act --
        renderer.update(content(Theme(accent: .green)), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))
        let grid = try #require(updated.grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .green)
        #expect(grid.foreground(column: 6, row: 0) == nil)
        #expect(grid.size == original.grid?.size)
        #expect(grid != original.grid)
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    private struct Counter: View {
        @State private var count = 0
        let palette: Theme
        var body: some View {
            Button("Count \(count)") { count += 1 }.foregroundStyle(.accent).theme(palette)
        }
    }

    @Test("Theme updates preserve mounted control state and focus")
    func mountedState() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(palette: Theme(accent: .red)))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(palette: Theme(accent: .green)), at: .now)
        _ = renderer.handle(.enter)
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Count 2")
        #expect(grid.foreground(column: 0, row: 0) == .green)
        #expect(grid.isFocused(column: 0, row: 0))
    }

    @Test("Unchanged theme output is suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Same").foregroundStyle(.accent).theme(Theme(accent: .green))
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let initial = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == initial)
    }
}
