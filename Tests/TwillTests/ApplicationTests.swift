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
        let runLoop = Twill.DefaultRunLoop()
        let application = Twill.Application(runLoop: runLoop)
        let timer = Twill.Timer(interval: .seconds(1), repeats: true) {
            ticks.append(clock.now)
        }
        runLoop.add(timer)

        // -- Act --
        let task = Task {
            await application.run()
        }
        defer { task.cancel() }
        try await clock.sleep(for: .milliseconds(2250))
        task.cancel()
        await task.value
        let countAfterCancellation = ticks.count
        try await clock.sleep(for: .milliseconds(1100))

        // -- Assert --
        #expect(ticks.count >= 2)
        #expect(ticks.count == countAfterCancellation)
        if let first = ticks.first {
            #expect(start.duration(to: first) >= .seconds(1))
        }
        for (previous, next) in zip(ticks, ticks.dropFirst()) {
            #expect(previous.duration(to: next) >= .milliseconds(900))
        }
    }

    @Test("An already cancelled application does not tick", .timeLimit(.minutes(1)))
    func cancelledBeforeRunning() async {
        // -- Arrange --
        var tickCount = 0
        let runLoop = Twill.DefaultRunLoop()
        let application = Twill.Application(runLoop: runLoop)
        let timer = Twill.Timer(interval: .seconds(1), repeats: true) {
            tickCount += 1
        }
        runLoop.add(timer)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }

            // -- Act --
            await application.run()
        }
        await task.value

        // -- Assert --
        #expect(tickCount == 0)
    }
}
