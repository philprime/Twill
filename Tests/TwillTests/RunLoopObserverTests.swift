import Dispatch
import Testing

@testable import Twill

@Suite("Run loop observers")
@MainActor
struct RunLoopObserverTests {
    @Test("Observers bracket source work and shutdown", .timeLimit(.minutes(1)))
    func sourceLifecycle() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var activities: [RunLoopActivity] = []
        var sourceActivities: [RunLoopActivity] = []
        runLoop.add(RunLoopObserver { activities.append($0) })
        let source = RunLoopSource {
            sourceActivities = activities
            runLoop.stop()
        }
        runLoop.add(source).signal()

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(sourceActivities == [.entry, .beforeWaiting, .afterWaiting, .beforeSources])
        #expect(activities == sourceActivities + [.exit])
    }

    @Test("Timer work has its own phase", .timeLimit(.minutes(1)))
    func timerPhase() async {
        // -- Arrange --
        let backend = RecordingRunLoopTimerBackend()
        let clock = ControlledRunLoopClock(now: DispatchTime(uptimeNanoseconds: 1_000_000_000))
        let runLoop = DefaultRunLoop(timerBackend: backend, now: { clock.now })
        var activities: [RunLoopActivity] = []
        runLoop.add(RunLoopObserver { activities.append($0) })
        runLoop.add(Twill.Timer(deadline: clock.now) { runLoop.stop() })
        var deadlines = backend.scheduledDeadlines.makeAsyncIterator()
        let task = Task { await runLoop.run() }
        _ = await deadlines.next()

        // -- Act --
        backend.fire()
        await task.value

        // -- Assert --
        #expect(activities.filter { $0 == .beforeTimers }.count == 1)
        #expect(!activities.contains(.beforeSources))
        #expect(activities.last == .exit)
    }

    @Test("Filtering, order, duplicate registration, and one-shot delivery", .timeLimit(.minutes(1)))
    func observerDelivery() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var calls: [Int] = []
        let first = RunLoopObserver(activities: [.beforeWaiting], repeats: false, order: -1) { _ in calls.append(1) }
        runLoop.add(RunLoopObserver(activities: [.beforeWaiting], order: 1) { _ in calls.append(3) })
        runLoop.add(first)
        runLoop.add(first)
        runLoop.add(RunLoopObserver(activities: [.beforeWaiting]) { _ in calls.append(2) })
        var sourceCalls = 0
        var registration: RunLoopSourceRegistration?
        let source = RunLoopSource {
            sourceCalls += 1
            if sourceCalls == 2 { runLoop.stop() } else { registration?.signal() }
        }
        registration = runLoop.add(source)
        registration?.signal()

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(Array(calls.prefix(3)) == [1, 2, 3])
        #expect(calls.filter { $0 == 1 }.count == 1)
        #expect(calls.filter { $0 == 2 }.count > 1)
        #expect(calls.filter { $0 == 2 }.count == calls.filter { $0 == 3 }.count)
    }

    @Test("Removal during delivery suppresses a later observer", .timeLimit(.minutes(1)))
    func removalDuringDelivery() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var calls = 0
        let removed = RunLoopObserver { _ in calls += 1 }
        runLoop.add(RunLoopObserver(activities: [.entry], order: -1) { _ in runLoop.remove(removed) })
        runLoop.add(removed)
        runLoop.add(RunLoopSource { runLoop.stop() }).signal()

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(calls == 0)
    }

    @Test("An observer can stop delivery before source work", .timeLimit(.minutes(1)))
    func stopFromObserver() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var sourceCalls = 0
        var exits = 0
        runLoop.add(RunLoopObserver(activities: [.beforeSources]) { _ in runLoop.stop() })
        runLoop.add(RunLoopObserver(activities: [.exit]) { _ in exits += 1 })
        runLoop.add(RunLoopSource { sourceCalls += 1 }).signal()

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(sourceCalls == 0)
        #expect(exits == 1)
    }

    @Test("Cancellation exits an idle loop without introducing timer wakes", .timeLimit(.minutes(1)))
    func idleCancellation() async {
        // -- Arrange --
        let backend = RecordingRunLoopTimerBackend()
        let runLoop = DefaultRunLoop(timerBackend: backend, now: { .now() })
        let (waiting, continuation) = AsyncStream<Void>.makeStream()
        var activities: [RunLoopActivity] = []
        runLoop.add(
            RunLoopObserver {
                activities.append($0)
                if $0 == .beforeWaiting { continuation.yield(()) }
            })
        let task = Task { await runLoop.run() }
        var iterator = waiting.makeAsyncIterator()
        _ = await iterator.next()

        // -- Act --
        task.cancel()
        await task.value
        continuation.finish()

        // -- Assert --
        #expect(activities == [.entry, .beforeWaiting, .exit])
        #expect(backend.scheduleCount == 0)
    }
}
