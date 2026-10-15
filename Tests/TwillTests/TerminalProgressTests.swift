import Testing

@testable import Twill

@Suite("Terminal-native progress")
@MainActor
struct TerminalProgressTests {
    @Test("Requests are deferred until activation and unchanged state is not written again")
    func deferredState() {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let session = DefaultTerminalSession(output: output)
        let progress = TerminalProgress(runLoop: runLoop, terminalSession: session)

        // -- Act --
        progress.state = .indeterminate
        let beforeStart = output.writes
        progress.start()
        progress.state = .indeterminate
        progress.state = .hidden
        progress.state = .hidden

        // -- Assert --
        #expect(beforeStart.isEmpty)
        #expect(output.writes == ["\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}"])
        #expect(runLoop.timers.count == 1)
        #expect(runLoop.cancelled.count == 1)
    }

    @Test("Keepalive runs only while active and stale deliveries do not write")
    func keepalive() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let session = DefaultTerminalSession(output: output)
        let progress = TerminalProgress(runLoop: runLoop, terminalSession: session)
        progress.start()
        #expect(runLoop.timers.isEmpty)

        // -- Act --
        progress.state = .indeterminate
        let timer = try #require(runLoop.timers.first)
        timer.action()
        progress.state = .hidden
        progress.state = .indeterminate
        timer.action()
        progress.stop()
        runLoop.timers.last?.action()
        progress.state = .hidden
        let beforeRestore = output.writes
        session.restore()

        // -- Assert --
        #expect(timer.repeats)
        #expect(timer.interval == .seconds(1))
        #expect(
            beforeRestore == [
                "\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}", "\u{1B}]9;4;3\u{7}",
            ])
        #expect(output.writes.last == "\u{1B}]9;4;0\u{7}")
        #expect(runLoop.cancelled.count == 2)
    }

    @Test("Nested activity preserves explicit state and returns the operation result")
    func nestedActivity() async {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let progress = TerminalProgress(
            runLoop: RecordingRunLoop(), terminalSession: DefaultTerminalSession(output: output))
        progress.start()

        // -- Act --
        let result = await progress.withActivity {
            await progress.withActivity {
                progress.state = .hidden
                return 42
            }
        }
        progress.state = .indeterminate
        await progress.withActivity {}
        let beforeHide = output.writes
        progress.state = .hidden

        // -- Assert --
        #expect(result == 42)
        #expect(beforeHide == ["\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}", "\u{1B}]9;4;3\u{7}"])
        #expect(output.writes.last == "\u{1B}]9;4;0\u{7}")
    }

    @Test("Overlapping activity stays visible until the final operation finishes")
    func overlappingActivity() async {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let progress = TerminalProgress(
            runLoop: RecordingRunLoop(), terminalSession: DefaultTerminalSession(output: output))
        progress.start()
        let (firstGate, finishFirst) = AsyncStream<Void>.makeStream()
        let (secondGate, finishSecond) = AsyncStream<Void>.makeStream()
        let (started, ready) = AsyncStream<Void>.makeStream()
        let first = Task {
            await progress.withActivity {
                ready.yield(())
                for await _ in firstGate {}
            }
        }
        let second = Task {
            await progress.withActivity {
                ready.yield(())
                for await _ in secondGate {}
            }
        }
        var iterator = started.makeAsyncIterator()
        _ = await iterator.next()
        _ = await iterator.next()

        // -- Act --
        finishFirst.finish()
        await first.value
        let afterFirst = output.writes
        finishSecond.finish()
        await second.value
        ready.finish()

        // -- Assert --
        #expect(afterFirst == ["\u{1B}]9;4;3\u{7}"])
        #expect(output.writes == ["\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}"])
    }

    @Test("Throwing and cancelled operations release scoped activity")
    func activityFailure() async {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let progress = TerminalProgress(
            runLoop: RecordingRunLoop(), terminalSession: DefaultTerminalSession(output: output))
        progress.start()
        let (gate, gateContinuation) = AsyncStream<Void>.makeStream()
        let (started, ready) = AsyncStream<Void>.makeStream()
        var receivedFailure = false

        // -- Act --
        do {
            try await progress.withActivity { throw Failure.output }
        } catch { receivedFailure = error is Failure }
        let task = Task {
            try await progress.withActivity {
                ready.yield(())
                ready.finish()
                for await _ in gate {}
                try Task.checkCancellation()
            }
        }
        for await _ in started {}
        task.cancel()
        let result = await task.result
        gateContinuation.finish()

        // -- Assert --
        #expect(receivedFailure)
        if case .failure(let error) = result {
            #expect(error is CancellationError)
        } else {
            Issue.record("Cancelled operation unexpectedly succeeded")
        }
        #expect(
            output.writes == [
                "\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}", "\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}",
            ])
    }

    @Test("Output failures are reported and partial progress writes still claim cleanup")
    func outputFailure() {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let session = DefaultTerminalSession(output: output)
        let progress = TerminalProgress(runLoop: runLoop, terminalSession: session)
        var reported = false
        progress.onError = { _ in reported = true }
        progress.start()
        output.nextFailure = Failure.output

        // -- Act --
        progress.state = .indeterminate
        progress.stop()
        session.restore()
        session.restore()

        // -- Assert --
        #expect(reported)
        #expect(output.writes == ["\u{1B}]9;4;0\u{7}"])
        #expect(runLoop.timers.isEmpty)
    }

    @Test("Keepalive and hide failures stop scheduling and preserve restoration", arguments: [false, true])
    func laterFailure(hide: Bool) throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let session = DefaultTerminalSession(output: output)
        let progress = TerminalProgress(runLoop: runLoop, terminalSession: session)
        var received: Error?
        progress.onError = { received = $0 }
        progress.start()
        progress.state = .indeterminate
        let timer = try #require(runLoop.timers.first)
        output.nextFailure = Failure.output

        // -- Act --
        if hide { progress.state = .hidden } else { timer.action() }
        timer.action()
        session.restore()

        // -- Assert --
        #expect(received is Failure)
        #expect(timer.isCancelled)
        #expect(output.writes == ["\u{1B}]9;4;3\u{7}", "\u{1B}]9;4;0\u{7}"])
    }

    @Test("An unused controller does not claim terminal progress cleanup")
    func unusedProgress() {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        let session = DefaultTerminalSession(output: output)
        let progress = TerminalProgress(runLoop: runLoop, terminalSession: session)

        // -- Act --
        progress.start()
        progress.stop()
        session.restore()

        // -- Assert --
        #expect(output.writes.isEmpty)
        #expect(runLoop.timers.isEmpty)
    }

    private enum Failure: Error { case output }
}
