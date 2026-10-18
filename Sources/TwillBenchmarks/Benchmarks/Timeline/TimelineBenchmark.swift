#if DEBUG || BENCHMARKING
    import Foundation

    @testable import Twill

    struct TimelineBenchmark: SDKBenchmark {
        enum Workload: String, CaseIterable {
            case changing = "timeline-isolation"
            case unchanged = "timeline-unchanged"
        }

        let workload: Workload
        var name: String { workload.rawValue }
        var summary: String { "Independent deadlines beside static content. Arguments: [rows=500] [iterations=20]" }

        func run(arguments: [String]) async throws -> BenchmarkResult {
            guard arguments.count <= 2,
                let count = Int(arguments.first ?? "500"), (1...10_000).contains(count),
                let iterations = Int(arguments.dropFirst().first ?? "20"), (1...10_000).contains(iterations)
            else { throw BenchmarkError.invalidArguments }
            return try measure(count: count, iterations: iterations)
        }

        private func measure(count: Int, iterations: Int) throws -> BenchmarkResult {
            let start = Date(timeIntervalSinceReferenceDate: 100)
            var fast = 0
            var slow = 0
            var staticBodies = 0
            let renderer = ViewRenderer.make(
                TimelineBenchmarkView(
                    start: start, rowCount: count, changesOutput: workload == .changing,
                    onFast: { fast += 1 }, onSlow: { slow += 1 }, onStatic: { staticBodies += 1 }))
            defer { renderer.unmount() }
            let proposal = ProposedCellSize(width: 120, height: 40)
            let initial = renderer.render(start, proposal: proposal).grid
            var refresh: [Duration] = []
            var drawing: [Duration] = []
            for index in 1...iterations {
                let date = start.addingTimeInterval(Double(index))
                let refreshStart = ContinuousClock.now
                renderer.refreshContent(at: date)
                refresh.append(refreshStart.duration(to: .now))
                let drawStart = ContinuousClock.now
                let frame = renderer.drawFrame(proposal: proposal)
                drawing.append(drawStart.duration(to: .now))
                guard frame?.size == CellSize(width: 120, height: 40),
                    staticBodies == count, fast == index + 1, slow == index / 10 + 1,
                    renderer.nextUpdate == date.addingTimeInterval(1),
                    workload != .unchanged || frame == initial
                else { throw BenchmarkError.incomplete(received: index - 1, expected: iterations) }
            }
            return BenchmarkResult(
                name: name, context: "\(count) static rows, 1s/10s deadlines, manual dates, 120x40, no terminal I/O",
                metrics: [
                    .milliseconds("content-refresh", samples: refresh),
                    .milliseconds("layout-and-draw", samples: drawing),
                    BenchmarkMetric(name: "static-body-evaluations", unit: "count", samples: [Double(staticBodies)]),
                    BenchmarkMetric(name: "fast-body-evaluations", unit: "count", samples: [Double(fast)]),
                    BenchmarkMetric(name: "slow-body-evaluations", unit: "count", samples: [Double(slow)]),
                ])
        }
    }
#endif
