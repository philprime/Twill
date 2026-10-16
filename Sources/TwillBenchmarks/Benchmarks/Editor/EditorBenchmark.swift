#if DEBUG || BENCHMARKING
    import Foundation

    @testable import Twill

    struct EditorBenchmark: SDKBenchmark {
        enum Workload: String, CaseIterable {
            case insert = "editor-insert"
            case navigate = "editor-navigate"
        }

        let workload: Workload
        var name: String { workload.rawValue }
        var summary: String { "Mixed-width multiline editing. Arguments: [lines=1000] [iterations=20]" }

        func run(arguments: [String]) async throws -> BenchmarkResult {
            guard arguments.count <= 2,
                let lines = Int(arguments.first ?? "1000"), (1...10_000).contains(lines),
                let iterations = Int(arguments.dropFirst().first ?? "20"), (1...10_000).contains(iterations)
            else { throw BenchmarkError.invalidArguments }
            return try measure(lines: lines, iterations: iterations)
        }

        private func measure(lines: Int, iterations: Int) throws -> BenchmarkResult {
            let original = String(repeating: "let value = \"界 👩🏽‍💻 é\" // synthetic document\n", count: lines)
            var text = original
            let root = TextEditor(text: Binding(get: { text }, set: { text = $0 })).frame(width: 120, height: 40)
            let renderer = ViewRenderer.make(root)
            defer { renderer.unmount() }
            let date = Date(timeIntervalSinceReferenceDate: 100)
            let proposal = ProposedCellSize(width: 120, height: 40)
            _ = renderer.render(date, proposal: proposal)
            var input: [Duration] = []
            var refresh: [Duration] = []
            var drawing: [Duration] = []
            for index in 0..<iterations {
                let key: KeyEvent =
                    workload == .insert
                    ? (index.isMultiple(of: 2) ? .a : .backspace)
                    : (index.isMultiple(of: 2) ? .arrowLeft : .arrowRight)
                let start = ContinuousClock.now
                let handled = renderer.handle(key)
                input.append(start.duration(to: .now))
                let refreshStart = ContinuousClock.now
                renderer.refreshContent(at: date)
                refresh.append(refreshStart.duration(to: .now))
                let drawStart = ContinuousClock.now
                _ = renderer.drawFrame(proposal: proposal)
                drawing.append(drawStart.duration(to: .now))
                guard handled, renderer.caretPosition != nil, renderer.nextUpdate == nil else {
                    throw BenchmarkError.incomplete(received: index, expected: iterations)
                }
            }
            let expected = original + (workload == .insert && !iterations.isMultiple(of: 2) ? "a" : "")
            guard text == expected else { throw BenchmarkError.incomplete(received: 0, expected: iterations) }
            let operation = workload == .insert ? "alternating insertion/backspace" : "alternating caret left/right"
            return BenchmarkResult(
                name: name,
                context: "\(lines) mixed-width lines, 120x40, no terminal I/O; \(operation)",
                metrics: [
                    .milliseconds("key-handling", samples: input),
                    .milliseconds("content-refresh", samples: refresh),
                    .milliseconds("layout-and-draw", samples: drawing),
                ])
        }
    }
#endif
