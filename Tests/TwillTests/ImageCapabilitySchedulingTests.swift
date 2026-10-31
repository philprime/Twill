import Foundation
import Testing

@testable import Twill

@Suite("Image capability scheduling")
@MainActor
struct ImageCapabilitySchedulingTests {
    private let png = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!

    @Test("Only the selected capability branch schedules, with independent sibling phases")
    func fallbackLifetime() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let image = try Image(pngData: png)
        var dates: [Date] = []
        func content(_ show: Bool) -> some View {
            VStack {
                if show {
                    ImageView(image, width: 4, height: 2) {
                        TimelineView(.periodic(from: start, by: 10)) { context in
                            dates.append(context.date)
                            return Text("Fallback")
                        }.id(1)
                    }
                }
                TimelineView(.periodic(from: start, by: 20)) { _ in Text("Sibling") }
            }
        }
        let supported = ViewRenderer.make(
            content(true), terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))
        let supportedFrame = supported.render(start)
        let unmounted = dates.isEmpty
        let fallback = ViewRenderer.make(content(true), terminalCapabilities: TerminalCapabilities())
        _ = fallback.render(start)
        weak var branch: ViewRenderer?
        branch = fallback.keyedNode(for: 1)

        // -- Act --
        fallback.update(content(true), at: start.addingTimeInterval(1))
        let updated = fallback.render(start.addingTimeInterval(1))
        let retained = branch != nil && branch === fallback.keyedNode(for: 1)
        _ = fallback.render(start.addingTimeInterval(10))
        fallback.update(content(false), at: start.addingTimeInterval(11))
        let removed = fallback.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(unmounted && supportedFrame.nextUpdate == start.addingTimeInterval(20))
        #expect(retained && branch == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start.addingTimeInterval(10)])
    }

    @Test("Unchanged images do not reupload on parent ticks and stop deletes owned placements")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let image = try Image(pngData: png)
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                ImageView(image, width: 4, height: 2) { Text("Fallback") }
            }, runLoop: loop, output: output, now: { now })
        try host.start(terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))
        let writes = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()
        let unchanged = output.writes == writes
        host.stop()

        // -- Assert --
        #expect(unchanged)
        #expect(output.writes.dropFirst(writes.count).contains { $0.contains("a=d,d=I") })
    }
}
