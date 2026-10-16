/// A self-contained SDK workload. Register new cases in the executable's suite.
@MainActor
protocol SDKBenchmark {
    var name: String { get }
    var summary: String { get }
    func run(arguments: [String]) async throws -> BenchmarkResult
}
