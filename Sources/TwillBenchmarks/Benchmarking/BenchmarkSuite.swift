@MainActor
struct BenchmarkSuite {
    let benchmarks: [any SDKBenchmark]

    func run(_ command: BenchmarkCommand) async throws -> [BenchmarkResult] {
        guard case .run(let name, let repetitions, let arguments) = command.action else { return [] }
        let selected: [any SDKBenchmark]
        if name == "all" {
            selected = benchmarks
        } else if let benchmark = benchmarks.first(where: { $0.name == name }) {
            selected = [benchmark]
        } else {
            throw BenchmarkError.unknownBenchmark(name)
        }
        var results: [BenchmarkResult] = []
        for benchmark in selected {
            for _ in 0..<repetitions {
                results.append(try await benchmark.run(arguments: arguments))
            }
        }
        return results
    }
}
