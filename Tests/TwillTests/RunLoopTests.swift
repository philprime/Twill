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

    @Test("Repeating timer actions can stop their application", .timeLimit(.minutes(1)))
    func repeatingTimerStopsApplication() async throws {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        let application = Application(runLoop: runLoop)
        var count = 0
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1), repeats: true) {
                MainActor.assertIsolated()
                count += 1
                if count == 3 { application.stop() }
            })

        // -- Act --
        try await application.run()

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
}
