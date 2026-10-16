import Testing

@testable import TwillBenchmarks

struct NavigationMetricsTests {
    @Test("The benchmark routes terminal input into list selection", .timeLimit(.minutes(1)))
    @MainActor
    func realTerminalNavigation() async throws {
        // -- Arrange --
        let count = 41

        // -- Act --
        let measurement = try await NavigationBenchmark.measure(count: count, rate: 1_000)
        let metrics = measurement.metrics

        // -- Assert --
        #expect(metrics.latencies.count == 41)
        #expect(metrics.latencies.allSatisfy { $0 >= .zero })
    }

    @Test func latencyAndDrain() {
        // -- Arrange --
        let metrics = NavigationMetrics(
            latencies: [.milliseconds(10), .milliseconds(30), .milliseconds(20)],
            releaseToCompletion: .milliseconds(50))

        // -- Act --
        let drain = metrics.drain

        // -- Assert --
        #expect(metrics.latencies == [.milliseconds(10), .milliseconds(30), .milliseconds(20)])
        #expect(drain == .milliseconds(50))
    }

    @Test func completionBeforeReleaseHasNoDrain() {
        // -- Arrange --
        let metrics = NavigationMetrics(latencies: [.milliseconds(2)], releaseToCompletion: .milliseconds(-10))

        // -- Act --
        let drain = metrics.drain

        // -- Assert --
        #expect(drain == .zero)
    }
}
