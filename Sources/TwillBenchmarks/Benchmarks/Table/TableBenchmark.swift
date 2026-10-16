// Renderer microbenchmarks use the same internal boundary as unit tests. The
// benchmark recipe enables it explicitly without changing production SDK builds.
#if DEBUG || BENCHMARKING
    import Foundation

    @testable import Twill

    /// Separates layout, input routing, and reconciliation costs on the same mounted fixture.
    struct TableBenchmark: SDKBenchmark {
        enum Workload: String, CaseIterable {
            case layout = "table-layout"
            case navigation = "table-navigation"
            case update = "table-update"
        }

        let workload: Workload
        var name: String { workload.rawValue }
        var summary: String {
            "Synthetic dashboard \(workload). Arguments: [rows=500] [iterations=20]"
        }

        func run(arguments: [String]) async throws -> BenchmarkResult {
            guard arguments.count <= 2,
                let rowCount = Int(arguments.first ?? "500"), (24...10_000).contains(rowCount),
                let iterations = Int(arguments.dropFirst().first ?? "20"), (1...10_000).contains(iterations)
            else { throw BenchmarkError.invalidArguments }
            return try measure(rowCount: rowCount, iterations: iterations)
        }

        private func measure(rowCount: Int, iterations: Int) throws -> BenchmarkResult {
            let rows = (0..<rowCount).map { TableBenchmarkView.Row(id: $0, name: "Worker \($0)", usage: $0 % 100) }
            var selection: Int? = 0
            let binding = Binding(get: { selection }, set: { selection = $0 })
            let root = TableBenchmarkView(rows: rows, selection: binding, revision: 0)
            let renderer = ViewRenderer.make(root)
            defer { renderer.unmount() }
            let date = Date(timeIntervalSinceReferenceDate: 100)
            let proposal = ProposedCellSize(width: 120, height: 40)
            let mountStart = ContinuousClock.now
            _ = renderer.render(date, proposal: proposal)
            let mount = mountStart.duration(to: .now)
            // Move from the search pane through the sortable header into the selected row.
            _ = renderer.handle(.tab)
            _ = renderer.handle(.arrowDown)
            _ = renderer.render(date, proposal: proposal)
            var samples: [Duration] = []
            var inputSamples: [Duration] = []
            for index in 0..<iterations {
                let start = ContinuousClock.now
                switch workload {
                case .layout:
                    _ = renderer.drawFrame(proposal: proposal)
                case .navigation:
                    let down = (index / 20).isMultiple(of: 2)
                    let expected = (selection ?? 0) + (down ? 1 : -1)
                    _ = renderer.handle(down ? .arrowDown : .arrowUp)
                    inputSamples.append(start.duration(to: .now))
                    guard selection == expected else {
                        throw BenchmarkError.incomplete(received: index, expected: iterations)
                    }
                    // External bindings do not invalidate a host, so explicitly supply the updated inputs.
                    renderer.update(TableBenchmarkView(rows: rows, selection: binding, revision: 0), at: date)
                    _ = renderer.render(date, proposal: proposal)
                case .update:
                    renderer.update(TableBenchmarkView(rows: rows, selection: binding, revision: index + 1), at: date)
                    _ = renderer.render(date, proposal: proposal)
                }
                samples.append(start.duration(to: .now))
            }
            var metrics: [BenchmarkMetric] = [
                .milliseconds("mount-and-first-frame", samples: [mount]),
                .milliseconds(workload.rawValue, samples: samples),
            ]
            if !inputSamples.isEmpty { metrics.append(.milliseconds("input-to-selection", samples: inputSamples)) }
            return BenchmarkResult(
                name: name,
                context:
                    "\(rowCount) rows, 5 columns, 120x40, cached SDK tree, no terminal I/O; "
                    + "navigation includes presentation",
                metrics: metrics)
        }
    }
#endif
