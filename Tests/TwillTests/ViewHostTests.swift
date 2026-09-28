import Foundation
import Testing

@testable import Twill

@Suite("View presentation lifecycle")
@MainActor
struct ViewHostTests {
    @Test("Static content writes one sanitized frame and creates no timers")
    func staticContent() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: Text("Hello\u{1B}[2J\nworld"), runLoop: runLoop, output: output)

        // -- Act --
        try host.start()
        host.stop()
        host.stop()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KHello [2J world", "\n"])
        #expect(runLoop.timers.isEmpty)
    }

    @Test("Static content remains idle until a key changes focus")
    func staticInputAfterIdle() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack {
                Text("A").focusable()
                Text("B").focusable()
            }, runLoop: runLoop, output: output
        )
        try host.start()
        #expect(runLoop.timers.isEmpty)
        let source = try #require(runLoop.sources.first)

        // -- Act --
        let handled = host.handle(.arrowRight)
        source.action()
        host.stop()

        // -- Assert --
        #expect(handled)
        #expect(runLoop.timers.isEmpty)
        #expect(runLoop.signalled.count == 1)
        #expect(output.writes.count == 3)
        #expect(output.writes[1].contains("\u{1B}[7mB\u{1B}[27m"))
    }

    @Test("Timeline ticks reuse the mounted schedule and shutdown cancels it")
    func timelineShutdown() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var now = Date(timeIntervalSinceReferenceDate: 100)
        var updates = 0
        let root = TimelineView(.periodic(from: now, by: 0.05)) { _ -> Text in
            updates += 1
            return Text("Tick \(updates)")
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
        try host.start()
        let first = try #require(runLoop.timers.last)

        // -- Act --
        now = now.addingTimeInterval(0.05)
        first.action()
        let pending = try #require(runLoop.timers.last)
        host.stop()
        pending.action()

        // -- Assert --
        #expect(updates == 2)
        #expect(runLoop.timers.count == 2)
        #expect(runLoop.cancelled.contains { $0 === pending })
        #expect(output.writes == ["\r\u{1B}[2KTick 1", "\r\u{1B}[5C2", "\n"])
    }

    @Test("The root body is not evaluated until presentation starts")
    func deferredMount() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        var bodyEvaluations = 0
        let host = ViewHost(
            rootView: MountProbe { bodyEvaluations += 1 },
            runLoop: RecordingRunLoop(), output: output
        )
        let evaluationsBeforeStart = bodyEvaluations
        let writesBeforeStart = output.writes

        // -- Act --
        try host.start()
        host.stop()

        // -- Assert --
        #expect(evaluationsBeforeStart == 0)
        #expect(writesBeforeStart.isEmpty)
        #expect(bodyEvaluations == 1)
        #expect(output.writes == ["\r\u{1B}[2KHello", "\n"])
    }

    @Test("An explicit empty root produces neither output nor timers")
    func emptyRoot() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(rootView: EmptyView(), runLoop: runLoop, output: output)

        // -- Act --
        try host.start()
        host.stop()

        // -- Assert --
        #expect(output.writes.isEmpty)
        #expect(runLoop.timers.isEmpty)
    }

    @Test("A failed scheduled write stops presentation and reports the original error")
    func failure() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        var frames = 0
        let root = TimelineView(.periodic(from: start, by: 0.05)) { _ -> Text in
            frames += 1
            return Text("Clock \(frames)")
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
        var reported: WriteFailure?
        host.onError = { reported = $0 as? WriteFailure }
        try host.start()
        let pending = try #require(runLoop.timers.last)
        output.failure = WriteFailure.failed

        // -- Act --
        now = start.addingTimeInterval(0.05)
        pending.action()

        // -- Assert --
        #expect(reported == .failed)
        #expect(runLoop.timers.count == 1)
        #expect(output.writes == ["\r\u{1B}[2KClock 1"])
    }
}

private struct MountProbe: View {
    let onBody: () -> Void

    var body: some View {
        onBody()
        return Text("Hello")
    }
}

private enum WriteFailure: Error { case failed }
