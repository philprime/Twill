import Testing
import Twill

@Suite("Run loop lifecycle")
@MainActor
struct RunLoopTests {
    @Test("A one-shot timer fires only once", .timeLimit(.minutes(1)))
    func oneShot() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        let timer = Twill.Timer(interval: .milliseconds(1)) { count += 1 }
        runLoop.add(timer)
        runLoop.add(timer)
        runLoop.add(Twill.Timer(interval: .milliseconds(30)) { runLoop.stop() })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(count == 1)
    }

    @Test("Repeating timer actions can stop their run loop", .timeLimit(.minutes(1)))
    func repeatingTimerStopsRunLoop() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1), repeats: true) {
                MainActor.assertIsolated()
                count += 1
                if count == 3 { runLoop.stop() }
            })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(count == 3)
    }

    @Test("Stopping before running discards queued registrations", .timeLimit(.minutes(1)))
    func stopBeforeRunning() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        runLoop.add(Twill.Timer(interval: .milliseconds(0)) { count += 1 })

        // -- Act --
        runLoop.stop()
        runLoop.stop()
        await runLoop.run()
        runLoop.add(Twill.Timer(interval: .milliseconds(0)) { count += 1 })
        await runLoop.run()

        // -- Assert --
        #expect(count == 0)
    }

    @Test("Cancellation wakes an idle loop", .timeLimit(.minutes(1)))
    func idleCancellation() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                continuation.yield(())
                continuation.finish()
            })
        var returned = false
        let task = Task {
            await runLoop.run()
            returned = true
        }
        for await _ in ready {}

        // -- Act --
        task.cancel()
        await task.value

        // -- Assert --
        #expect(returned)
    }

    @Test("Shutdown releases registrations that never activated", .timeLimit(.minutes(1)))
    func releasesPendingRegistrations() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        weak var pending: Twill.Timer?
        do {
            let timer = Twill.Timer(interval: .seconds(1)) {}
            pending = timer
            runLoop.add(timer)
            runLoop.add(timer)
        }

        // -- Act --
        runLoop.stop()
        await runLoop.run()

        // -- Assert --
        #expect(pending == nil)
    }

    @Test("Cancellation suppresses pending and repeating timers", .timeLimit(.minutes(1)), arguments: [false, true])
    func cancelsTimer(beforeActivation: Bool) async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        let timer = Twill.Timer(interval: .milliseconds(1), repeats: true) { count += 1 }
        runLoop.add(timer)
        var countAtCancellation = 0
        if beforeActivation {
            runLoop.cancel(timer)
        } else {
            runLoop.add(
                Twill.Timer(interval: .milliseconds(10)) {
                    runLoop.cancel(timer)
                    countAtCancellation = count
                })
        }
        runLoop.add(Twill.Timer(interval: .milliseconds(30)) { runLoop.stop() })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(count == countAtCancellation)
        if !beforeActivation { #expect(count > 0) }
    }

    @Test("An action can register another timer", .timeLimit(.minutes(1)))
    func registrationFromCallback() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var actions: [Int] = []
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                actions.append(1)
                runLoop.add(
                    Twill.Timer(interval: .milliseconds(1)) {
                        actions.append(2)
                        runLoop.stop()
                    })
            })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(actions == [1, 2])
    }

    @Test("Repeated source signals coalesce until delivery", .timeLimit(.minutes(1)))
    func coalescesSourceSignals() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        let source = RunLoopSource {
            count += 1
            runLoop.stop()
        }
        runLoop.add(source)

        // -- Act --
        runLoop.signal(source)
        runLoop.signal(source)
        await runLoop.run()

        // -- Assert --
        #expect(count == 1)
    }

    @Test("Consuming readiness suppresses its stale notification but permits a later signal", .timeLimit(.minutes(1)))
    func consumesSourceReadiness() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        let source = RunLoopSource {
            count += 1
            runLoop.stop()
        }
        runLoop.add(source)
        runLoop.signal(source)

        // -- Act --
        runLoop.consume(source)
        runLoop.signal(source)
        await runLoop.run()

        // -- Assert --
        #expect(count == 1)
    }

    @Test(
        "Removing and re-registering a source discards notifications from its old registration", .timeLimit(.minutes(1))
    )
    func reRegistersSource() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var count = 0
        let source = RunLoopSource {
            count += 1
            runLoop.stop()
        }
        runLoop.add(source)
        runLoop.signal(source)

        // -- Act --
        runLoop.remove(source)
        runLoop.add(source)
        runLoop.signal(source)
        await runLoop.run()

        // -- Assert --
        #expect(count == 1)
    }
}
