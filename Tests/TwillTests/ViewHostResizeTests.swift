import Foundation
import Testing

@testable import Twill

@Suite("Event-driven viewport layout")
@MainActor
struct ViewHostResizeTests {
    @Test("Fullscreen root content is centered within the viewport and recenters on resize")
    func centeredFullscreenRoot() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: VStack { Text("Hello") }, runLoop: RecordingRunLoop(), output: output)

        // -- Act --
        try host.start(size: TerminalSize(columns: 11, rows: 5), mode: .fullscreen)
        try host.resize(to: TerminalSize(columns: 9, rows: 3))
        host.stop()

        // -- Assert --
        #expect(output.writes.count == 2)
        #expect(output.writes[0].contains("\r\u{1B}[2K   Hello   "))
        #expect(output.writes[1].contains("\r\u{1B}[2K  Hello  "))
    }

    @Test("Resize redraws cached content and preserves the pending timeline timer")
    func resizeTimeline() throws {
        // -- Arrange --
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var evaluations = 0
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            evaluations += 1
            return Text("ABCDEF")
        }
        let host = ViewHost(rootView: root, runLoop: loop, output: output, now: { start })
        try host.start(size: TerminalSize(columns: 3, rows: 2))
        let timer = try #require(loop.timers.last)

        // -- Act --
        try host.resize(to: TerminalSize(columns: 6, rows: 2))
        try host.resize(to: TerminalSize(columns: 2, rows: 1))
        try host.resize(to: TerminalSize(columns: 2, rows: 1))

        // -- Assert --
        #expect(evaluations == 1)
        #expect(loop.timers.count == 1)
        #expect(loop.timers.last === timer)
        #expect(loop.cancelled.isEmpty)
        #expect(output.writes == ["\r\u{1B}[2KABC", "\r\u{1B}[2KABCDEF", "\r\u{1B}[2KAB"])
        host.stop()
    }

    @Test("Static content redraws on resize without scheduling polling")
    func staticResize() throws {
        // -- Arrange --
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: Text("ABC"), runLoop: loop, output: output)
        try host.start(size: TerminalSize(columns: 2, rows: 1))

        // -- Act --
        try host.resize(to: TerminalSize(columns: 4, rows: 1))
        host.stop()
        try host.resize(to: TerminalSize(columns: 1, rows: 1))

        // -- Assert --
        #expect(loop.timers.isEmpty)
        #expect(output.writes == ["\r\u{1B}[2KAB", "\r\u{1B}[2KABC", "\n"])
    }

    @Test("Resize failures propagate to the stream consumer without advancing the frame baseline")
    func resizeFailure() throws {
        // -- Arrange --
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: Text("ABC"), runLoop: loop, output: output)
        try host.start(size: TerminalSize(columns: 2, rows: 1))
        output.failure = Failure.output
        var received: Failure?

        // -- Act --
        do { try host.resize(to: TerminalSize(columns: 3, rows: 1)) } catch { received = error as? Failure }
        host.stop()

        // -- Assert --
        #expect(received == .output)
        #expect(output.writes == ["\r\u{1B}[2KAB"])
    }

    private enum Failure: Error { case output }
}
