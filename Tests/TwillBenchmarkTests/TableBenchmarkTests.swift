#if DEBUG || BENCHMARKING
    import Testing

    @testable import TwillBenchmarks

    @MainActor
    struct TableBenchmarkTests {
        @Test("Each table workload measures a fresh SDK fixture", arguments: TableBenchmark.Workload.allCases)
        func workloads(workload: TableBenchmark.Workload) async throws {
            // -- Arrange --
            let benchmark = TableBenchmark(workload: workload)

            // -- Act --
            let result = try await benchmark.run(arguments: ["24", "42"])

            // -- Assert --
            #expect(result.name == workload.rawValue)
            #expect(result.metrics[0].samples.count == 1)
            #expect(result.metrics[1].samples.count == 42)
            #expect(result.metrics.allSatisfy { $0.samples.allSatisfy { $0 >= 0 } })
            if workload == .navigation {
                #expect(result.metrics.last?.name == "input-to-selection")
                #expect(result.metrics.last?.samples.count == 42)
            }
        }

        @Test("Invalid workload sizes are rejected")
        func invalidArguments() async {
            // -- Arrange --
            let benchmark = TableBenchmark(workload: .layout)

            // -- Act --
            for arguments in [["0"], ["23"], ["500", "0"], ["invalid"], ["24", "2", "extra"]] {
                await #expect(throws: BenchmarkError.self) { try await benchmark.run(arguments: arguments) }
            }

            // -- Assert --
            #expect(benchmark.name == "table-layout")
        }
    }
#endif
