#if DEBUG || BENCHMARKING
    import Foundation

    @testable import Twill

    struct CollectionBenchmark: SDKBenchmark {
        enum Workload: String, CaseIterable {
            case reorder = "collection-reorder"
            case replace = "collection-replace"
        }

        let workload: Workload
        var name: String { workload.rawValue }
        var summary: String { "Keyed collection updates. Arguments: [rows=500] [iterations=20]" }

        func run(arguments: [String]) async throws -> BenchmarkResult {
            guard arguments.count <= 2,
                let count = Int(arguments.first ?? "500"), (1...10_000).contains(count),
                let iterations = Int(arguments.dropFirst().first ?? "20"), (1...10_000).contains(iterations)
            else { throw BenchmarkError.invalidArguments }
            return try measure(count: count, iterations: iterations)
        }

        private func measure(count: Int, iterations: Int) throws -> BenchmarkResult {
            var identifiers = Array(0..<count)
            let renderer = ViewRenderer.make(CollectionBenchmarkView(identifiers: identifiers))
            defer { renderer.unmount() }
            let date = Date(timeIntervalSinceReferenceDate: 100)
            let proposal = ProposedCellSize(width: 120, height: 40)
            _ = renderer.render(date, proposal: proposal)
            var reconciliation: [Duration] = []
            var drawing: [Duration] = []
            for index in 0..<iterations {
                // Rotate stable keys or replace a quarter of the collection, keeping its size constant.
                let replaced = max(1, count / 4)
                if workload == .reorder {
                    identifiers = Array(identifiers.dropFirst()) + [identifiers[0]]
                } else {
                    let first = count + index * replaced
                    identifiers = Array(identifiers.dropFirst(replaced)) + Array(first..<(first + replaced))
                }
                let root = CollectionBenchmarkView(identifiers: identifiers)
                let start = ContinuousClock.now
                renderer.update(root, at: date)
                reconciliation.append(start.duration(to: .now))
                let drawStart = ContinuousClock.now
                let frame = renderer.drawFrame(proposal: proposal)
                drawing.append(drawStart.duration(to: .now))
                let displaysFirstKey = String(identifiers[0]).enumerated().allSatisfy {
                    frame?[$0.offset, 0] == .glyph($0.element, width: 1)
                }
                guard displaysFirstKey, frame?.size == CellSize(width: 120, height: 40), renderer.nextUpdate == nil
                else {
                    throw BenchmarkError.incomplete(received: index, expected: iterations)
                }
            }
            return BenchmarkResult(
                name: name, context: "\(count) keyed rows, 120x40, no terminal I/O; fixture mutations excluded",
                metrics: [
                    .milliseconds("reconcile", samples: reconciliation),
                    .milliseconds("layout-and-draw", samples: drawing),
                ])
        }
    }
#endif
