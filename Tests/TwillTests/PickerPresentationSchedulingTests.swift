import Foundation
import Testing

@testable import Twill

@Suite("Picker presentation scheduling")
@MainActor
struct PickerPresentationSchedulingTests {
    @Test(
        "Option updates retain independent phases and removal drops option schedules",
        arguments: [PickerPresentation.inline, .compact, .vertical])
    func independentDeadlines(mode: PickerPresentation) {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Int: [Date]] = [:]
        var siblingDates: [Date] = []
        func content(_ options: [Int]) -> some View {
            HStack {
                Picker("Mode", selection: .constant(0), options: options, presentation: mode) { option in
                    TimelineView(.periodic(from: start, by: option == 0 ? 10 : 20)) { context in
                        dates[option, default: []].append(context.date)
                        return Text("\(option)")
                    }
                }
                TimelineView(.periodic(from: start, by: 30)) { context in
                    siblingDates.append(context.date)
                    return Text("S")
                }
            }
        }
        let renderer = ViewRenderer.make(content([0, 1]))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content([1, 0]), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content([]), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(30))
        #expect(dates[0] == [start, start, start.addingTimeInterval(10)])
        #expect(mode == .compact ? dates[1] == nil : dates[1] == [start, start])
        #expect(siblingDates == [start, start, start])
    }

    @Test("Unchanged vertical picker output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Picker("Mode", selection: .constant("B"), options: ["A", "B"], presentation: .vertical)
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
