#if DEBUG || BENCHMARKING
    import Testing

    @testable import TwillBenchmarks

    @MainActor
    struct AdditionalWorkloadTests {
        @Test("Keyed collection workloads keep a bounded viewport", arguments: CollectionBenchmark.Workload.allCases)
        func collections(workload: CollectionBenchmark.Workload) async throws {
            // -- Arrange --
            let benchmark = CollectionBenchmark(workload: workload)

            // -- Act --
            let result = try await benchmark.run(arguments: ["24", "3"])

            // -- Assert --
            #expect(result.name == workload.rawValue)
            #expect(result.metrics.map(\.name) == ["reconcile", "layout-and-draw"])
            #expect(result.metrics.allSatisfy { $0.samples.count == 3 && $0.samples.allSatisfy { $0 >= 0 } })
        }

        @Test(
            "Editor workloads preserve text through insertion and navigation",
            arguments: EditorBenchmark.Workload.allCases)
        func editors(workload: EditorBenchmark.Workload) async throws {
            // -- Arrange --
            let benchmark = EditorBenchmark(workload: workload)

            // -- Act --
            let odd = try await benchmark.run(arguments: ["20", "3"])
            let even = try await benchmark.run(arguments: ["20", "4"])

            // -- Assert --
            #expect(odd.name == workload.rawValue)
            #expect(odd.metrics.map(\.name) == ["key-handling", "content-refresh", "layout-and-draw"])
            #expect(odd.metrics.allSatisfy { $0.samples.count == 3 && $0.samples.allSatisfy { $0 >= 0 } })
            #expect(even.metrics.allSatisfy { $0.samples.count == 4 && $0.samples.allSatisfy { $0 >= 0 } })
        }

        @Test(
            "Controlled timeline workloads preserve sibling schedules", arguments: TimelineBenchmark.Workload.allCases)
        func timelines(workload: TimelineBenchmark.Workload) async throws {
            // -- Arrange --
            let benchmark = TimelineBenchmark(workload: workload)

            // -- Act --
            let result = try await benchmark.run(arguments: ["24", "21"])

            // -- Assert --
            #expect(result.name == workload.rawValue)
            #expect(result.metrics[0].samples.count == 21)
            #expect(result.metrics[1].samples.count == 21)
            #expect(result.metrics[2].samples == [24])
            #expect(result.metrics[3].samples == [22])
            #expect(result.metrics[4].samples == [3])
        }

        @Test("Workloads reject invalid sizes before allocating fixtures")
        func invalidArguments() async throws {
            // -- Arrange --
            let benchmarks: [any SDKBenchmark] = [
                CollectionBenchmark(workload: .replace), EditorBenchmark(workload: .insert),
                TimelineBenchmark(workload: .changing),
            ]

            let invalid = [["0"], ["10001"], ["1", "0"], ["invalid"], ["1", "2", "extra"]]
            var rejected = 0

            // -- Act --
            for benchmark in benchmarks {
                for arguments in invalid {
                    do {
                        _ = try await benchmark.run(arguments: arguments)
                    } catch BenchmarkError.invalidArguments {
                        rejected += 1
                    }
                }
            }

            // -- Assert --
            #expect(rejected == benchmarks.count * invalid.count)
        }
    }
#endif
