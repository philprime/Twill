#if DEBUG || BENCHMARKING
    import Testing

    @testable import TwillBenchmarks

    @MainActor
    struct GraphRasterBenchmarkTests {
        @Test("Graph resize workload draws RGBA images at alternating viewport sizes")
        func redraws() async throws {
            // -- Arrange --
            let benchmark = GraphRasterBenchmark()

            // -- Act --
            let result = try await benchmark.run(arguments: ["4", "2", "12", "8"])

            // -- Assert --
            #expect(result.name == "graph-raster")
            #expect(result.metrics.map(\.name) == ["resize-layout-and-draw", "rgba-bytes"])
            #expect(result.metrics[0].samples.count == 2)
            #expect(result.metrics[0].samples.allSatisfy { $0 > 0 })
            #expect(result.metrics[1].samples == [43_008, 53_248])
        }

        @Test("Graph raster workload rejects invalid sizes before drawing")
        func invalidArguments() async {
            // -- Arrange --
            let benchmark = GraphRasterBenchmark()
            let invalid = [
                ["1"], ["257"], ["4", "0"], ["4", "1", "0"], ["4", "1", "12", "1"],
                ["invalid"], ["4", "1", "12", "8", "extra"],
            ]

            // -- Act --
            for arguments in invalid {
                await #expect(throws: BenchmarkError.self) { try await benchmark.run(arguments: arguments) }
            }

            // -- Assert --
            #expect(benchmark.name == "graph-raster")
        }
    }
#endif
