import Dispatch
import Testing

@testable import Twill

@Suite("Run loop idle efficiency")
@MainActor
struct RunLoopIdleTests {
    @Test("Removing the last deadline disarms the backend and source events need no timer", .timeLimit(.minutes(1)))
    func idleAfterLastTimerCancellation() async {
        // -- Arrange --
        let backend = RecordingRunLoopTimerBackend()
        let clock = ControlledRunLoopClock(now: DispatchTime(uptimeNanoseconds: 1_000_000_000))
        let afterDeadline = clock.now + .seconds(10)
        let runLoop = DefaultRunLoop(timerBackend: backend, now: { clock.now })
        var timerCalls = 0
        var sourceCalls = 0
        let (deliveries, continuation) = AsyncStream<Void>.makeStream()
        var iterator = deliveries.makeAsyncIterator()
        let source = RunLoopSource {
            sourceCalls += 1
            continuation.yield(())
        }
        runLoop.add(source)
        let timer = Twill.Timer(deadline: clock.now + .seconds(1)) { timerCalls += 1 }
        runLoop.add(timer)
        var deadlines = backend.scheduledDeadlines.makeAsyncIterator()
        let task = Task { await runLoop.run() }
        _ = await deadlines.next()

        // -- Act --
        runLoop.cancel(timer)
        runLoop.signal(source)
        _ = await iterator.next()
        clock.now = afterDeadline
        backend.fire()
        runLoop.signal(source)
        _ = await iterator.next()
        task.cancel()
        await task.value
        continuation.finish()

        // -- Assert --
        #expect(timerCalls == 0)
        #expect(sourceCalls == 2)
        #expect(backend.scheduleCount == 1)
        #expect(backend.disarmCount == 1)
        #expect(backend.stopCount == 1)
    }
}
