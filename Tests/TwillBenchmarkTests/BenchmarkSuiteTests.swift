import Testing

@testable import TwillBenchmarks

@MainActor
struct BenchmarkSuiteTests {
    @Test("Named selection runs only the requested benchmark and preserves its arguments")
    func namedSelection() async throws {
        // -- Arrange --
        let suite = BenchmarkSuite(benchmarks: [ArgumentBenchmark(name: "first"), ArgumentBenchmark(name: "second")])
        let command = try BenchmarkCommand(arguments: ["second", "--repeat", "2", "--", "7"])

        // -- Act --
        let results = try await suite.run(command)

        // -- Assert --
        #expect(results.map(\.name) == ["second", "second"])
        #expect(results.map { $0.metrics[0].samples } == [[7], [7]])
    }

    @Test("All benchmarks run in registration order")
    func allBenchmarks() async throws {
        // -- Arrange --
        let suite = BenchmarkSuite(benchmarks: [ArgumentBenchmark(name: "first"), ArgumentBenchmark(name: "second")])
        let command = try BenchmarkCommand(arguments: [])

        // -- Act --
        let results = try await suite.run(command)

        // -- Assert --
        #expect(results.map(\.name) == ["first", "second"])
    }

    @Test("Unknown benchmarks and invalid repetition counts are rejected")
    func invalidSelection() async throws {
        // -- Arrange --
        let suite = BenchmarkSuite(benchmarks: [ArgumentBenchmark(name: "known")])
        let command = try BenchmarkCommand(arguments: ["missing"])

        // -- Act --
        await #expect(throws: BenchmarkError.self) { try await suite.run(command) }

        // -- Assert --
        #expect(throws: BenchmarkError.self) { try BenchmarkCommand(arguments: ["all", "--repeat", "0"]) }
        #expect(throws: BenchmarkError.self) { try BenchmarkCommand(arguments: ["all", "--repeat"]) }
        #expect(throws: BenchmarkError.self) { try BenchmarkCommand(arguments: ["all", "--unknown"]) }
    }

    @Test("List and help do not execute workloads")
    func informationalCommands() async throws {
        // -- Arrange --
        let suite = BenchmarkSuite(benchmarks: [ArgumentBenchmark(name: "known")])

        // -- Act --
        let listed = try await suite.run(BenchmarkCommand(arguments: ["--list"]))
        let helped = try await suite.run(BenchmarkCommand(arguments: ["--help"]))

        // -- Assert --
        #expect(listed.isEmpty)
        #expect(helped.isEmpty)
    }

    private struct ArgumentBenchmark: SDKBenchmark {
        let name: String
        var summary: String { "Exercises argument forwarding" }

        func run(arguments: [String]) async throws -> BenchmarkResult {
            BenchmarkResult(
                name: name, context: "test",
                metrics: [BenchmarkMetric(name: "value", unit: "count", samples: [Double(arguments.first ?? "1")!])])
        }
    }
}
