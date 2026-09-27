#if TESTING
    import Foundation
    import Testing
    @testable import Twill

    @Suite("Coalesced mounted presentation")
    @MainActor
    struct ViewHostSchedulingTests {
        @Test("Independent timelines share one wake-up and one write at a common deadline")
        func sharedWake() throws {
            // -- Arrange --
            let runLoop = RecordingRunLoop()
            let output = RecordingTerminalOutput()
            let start = Date(timeIntervalSinceReferenceDate: 100)
            var now = start
            var fast = 0
            var slow = 0
            let root = HStack {
                TimelineView(.periodic(from: start, by: 0.05)) { _ -> Text in
                    fast += 1
                    return Text("F\(fast)")
                }
                TimelineView(.periodic(from: start, by: 1)) { _ -> Text in
                    slow += 1
                    return Text("S\(slow)")
                }
            }
            let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
            try host.start()

            // -- Act --
            now = start.addingTimeInterval(0.05)
            try #require(runLoop.timers.last).action()
            now = start.addingTimeInterval(1)
            try #require(runLoop.timers.last).action()
            host.stop()

            // -- Assert --
            #expect(fast == 3)
            #expect(slow == 2)
            #expect(runLoop.timers.count == 3)
            #expect(runLoop.cancelled.count == 1)
            #expect(output.writes == ["\r\u{1B}[2KF1 S1", "\r\u{1B}[2KF2 S1", "\r\u{1B}[2KF3 S2", "\n"])
        }

        @Test("A static stack presents once and schedules no wake-ups")
        func idleStaticStack() throws {
            // -- Arrange --
            let runLoop = RecordingRunLoop()
            let output = RecordingTerminalOutput()
            let root = HStack {
                Text("Static")
                EmptyView()
                Text("UI")
            }
            let host = ViewHost(rootView: root, runLoop: runLoop, output: output)

            // -- Act --
            try host.start()
            host.stop()

            // -- Assert --
            #expect(runLoop.timers.isEmpty)
            #expect(output.writes == ["\r\u{1B}[2KStatic UI", "\n"])
        }

        @Test("Unchanged presentation is not written again")
        func unchangedOutput() throws {
            // -- Arrange --
            let runLoop = RecordingRunLoop()
            let output = RecordingTerminalOutput()
            let start = Date(timeIntervalSinceReferenceDate: 100)
            var now = start
            var evaluations = 0
            let root = TimelineView(.periodic(from: start, by: 0.05)) { _ -> Text in
                evaluations += 1
                return Text("Unchanged")
            }
            let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
            try host.start()

            // -- Act --
            now = start.addingTimeInterval(0.05)
            try #require(runLoop.timers.last).action()
            host.stop()

            // -- Assert --
            #expect(evaluations == 2)
            #expect(output.writes == ["\r\u{1B}[2KUnchanged", "\n"])
        }

        @Test("Removing the final visible branch clears previously presented content")
        func clearsRemovedContent() throws {
            // -- Arrange --
            let runLoop = RecordingRunLoop()
            let output = RecordingTerminalOutput()
            let start = Date(timeIntervalSinceReferenceDate: 100)
            var now = start
            let root = TimelineView(.periodic(from: start, by: 0.05)) { context in
                HStack {
                    if context.date == start { Text("Visible") }
                }
            }
            let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
            try host.start()

            // -- Act --
            now = start.addingTimeInterval(0.05)
            try #require(runLoop.timers.last).action()
            host.stop()

            // -- Assert --
            #expect(output.writes == ["\r\u{1B}[2KVisible", "\r\u{1B}[2K", "\n"])
        }
    }
#endif
