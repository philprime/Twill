import Testing
import Twill

@Suite("Application clock")
@MainActor
struct ApplicationTests {
    @Test("Ticks once per second and stops when cancelled", .timeLimit(.minutes(1)))
    func clockTicks() async throws {
        // -- Arrange --
        let clock = ContinuousClock()
        let start = clock.now
        var ticks: [ContinuousClock.Instant] = []
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        let runLoop = Twill.DefaultRunLoop()
        let terminal = try TestTerminal()
        let application = terminal.makeApplication(runLoop: runLoop)
        let timer = Twill.Timer(interval: .seconds(1), repeats: true) {
            ticks.append(clock.now)
            if ticks.count == 2 {
                continuation.yield(())
                continuation.finish()
            }
        }
        runLoop.add(timer)

        // -- Act --
        let task = Task {
            try await application.run()
        }
        defer { task.cancel() }
        for await _ in ready {}
        task.cancel()
        try await task.value
        let countAfterCancellation = ticks.count
        try await clock.sleep(for: .milliseconds(1100))

        // -- Assert --
        #expect(ticks.count >= 2)
        #expect(ticks.count == countAfterCancellation)
        // Deadlines preserve phase, so delayed delivery can shorten the gap between callbacks.
        for (index, tick) in ticks.enumerated() {
            #expect(start.duration(to: tick) >= .seconds(index + 1))
        }
    }

    @Test("An already cancelled application does not tick", .timeLimit(.minutes(1)))
    func cancelledBeforeRunning() async throws {
        // -- Arrange --
        var tickCount = 0
        let runLoop = Twill.DefaultRunLoop()
        let terminal = try TestTerminal()
        let application = terminal.makeApplication(runLoop: runLoop)
        let timer = Twill.Timer(interval: .seconds(1), repeats: true) {
            tickCount += 1
        }
        runLoop.add(timer)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }

            // -- Act --
            try await application.run()
        }
        try await task.value

        // -- Assert --
        #expect(tickCount == 0)
    }
}
