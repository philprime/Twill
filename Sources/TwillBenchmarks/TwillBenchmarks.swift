import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@main
@MainActor
struct TwillBenchmarks {
    static func main() async {
        do {
            var benchmarks: [any SDKBenchmark] = [NavigationBenchmark()]
            #if DEBUG || BENCHMARKING
                benchmarks += TableBenchmark.Workload.allCases.map { TableBenchmark(workload: $0) }
                benchmarks += CollectionBenchmark.Workload.allCases.map { CollectionBenchmark(workload: $0) }
                benchmarks += EditorBenchmark.Workload.allCases.map { EditorBenchmark(workload: $0) }
                benchmarks += TimelineBenchmark.Workload.allCases.map { TimelineBenchmark(workload: $0) }
                benchmarks.append(GraphRasterBenchmark())
            #endif
            let suite = BenchmarkSuite(benchmarks: benchmarks)
            let command = try BenchmarkCommand(arguments: Array(CommandLine.arguments.dropFirst()))
            switch command.action {
            case .help:
                print("Usage: TwillBenchmarks [all|name] [--repeat N] [-- benchmark-arguments...]")
                print("Use --list to discover cases. Each repetition creates a fresh workload.")
                print("Metrics are descriptive, with no machine-dependent pass/fail thresholds.")
            case .list:
                for benchmark in suite.benchmarks { print("\(benchmark.name): \(benchmark.summary)") }
            case .run:
                for result in try await suite.run(command) { print(result.formatted) }
            }
        } catch {
            let message = "Benchmark failed: \(error). Use --help or --list for usage.\n"
            try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
