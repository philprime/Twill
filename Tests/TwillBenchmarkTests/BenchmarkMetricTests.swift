import Testing

@testable import TwillBenchmarks

struct BenchmarkMetricTests {
    @Test("Percentiles use nearest rank without changing sample order")
    func percentiles() {
        // -- Arrange --
        let metric = BenchmarkMetric(name: "layout", unit: "ms", samples: [30, 10, 20, 40])

        // -- Act --
        let median = metric.percentile(0.5)
        let high = metric.percentile(0.95)

        // -- Assert --
        #expect(median == 20)
        #expect(high == 40)
        #expect(metric.samples == [30, 10, 20, 40])
    }

    @Test("Duration measurements are reported in milliseconds")
    func durationUnits() {
        // -- Arrange --
        let durations: [Duration] = [.microseconds(250), .milliseconds(1500)]

        // -- Act --
        let metric = BenchmarkMetric.milliseconds("latency", samples: durations)

        // -- Assert --
        #expect(metric.unit == "ms")
        #expect(metric.samples == [0.25, 1500])
    }
}
