#if DEBUG || BENCHMARKING
    import Foundation
    import TwillGraphs

    @testable import Twill

    struct GraphRasterBenchmark: SDKBenchmark {
        let name = "graph-raster"
        let summary =
            "Directed diagonal edges and circular nodes. Arguments: [nodes=48] [iterations=3] [columns=120] [rows=40]"

        func run(arguments: [String]) async throws -> BenchmarkResult {
            guard arguments.count <= 4,
                let nodes = Int(arguments.first ?? "48"), (4...256).contains(nodes),
                let iterations = Int(arguments.dropFirst().first ?? "3"), (1...100).contains(iterations),
                let columns = Int(arguments.dropFirst(2).first ?? "120"), (8...240).contains(columns),
                let rows = Int(arguments.dropFirst(3).first ?? "40"), (4...80).contains(rows)
            else { throw BenchmarkError.invalidArguments }
            return try measure(nodes: nodes, iterations: iterations, columns: columns, rows: rows)
        }

        private func measure(nodes: Int, iterations: Int, columns: Int, rows: Int) throws -> BenchmarkResult {
            // Diametrically opposed edges reproduce large stroke bounding boxes
            // without package extraction, force simulation, or a terminal session.
            let graph = try GraphNetwork(
                nodes: (0..<nodes).map { GraphNode(id: $0, label: "Type\($0)") },
                edges: (0..<nodes).map { GraphEdge(from: $0, to: ($0 + nodes / 2) % nodes, directed: true) })
            let positions = Dictionary(
                uniqueKeysWithValues: (0..<nodes).map { index in
                    let angle = Double(index) * 2 * Double.pi / Double(nodes)
                    return (index, PixelPoint(x: cos(angle) * 100, y: sin(angle) * 100))
                })
            let renderer = ViewRenderer.make(GraphView(graph, positions: positions, labels: .automatic))
            defer { renderer.unmount() }
            // Mount once. Subsequent draws follow the cached-content resize path
            // observed in the trace, rather than measuring view reconciliation.
            _ = renderer.render(
                Date(timeIntervalSinceReferenceDate: 100),
                proposal: ProposedCellSize(width: columns, height: rows))
            var drawing: [Duration] = []
            var bytes: [Double] = []
            // Swift's body-skipping symbol extraction crashes when serializing
            // for-loop and conditional bindings here. Use ordinary local bindings.
            var index = 0
            while index < iterations {
                let delta = index % 2
                let proposal = ProposedCellSize(width: columns + delta, height: rows + delta)
                let start = ContinuousClock.now
                let frame = renderer.drawFrame(proposal: proposal)
                drawing.append(start.duration(to: .now))
                let images = frame?.images ?? []
                guard images.count == 1 else {
                    throw BenchmarkError.incomplete(received: index, expected: iterations)
                }
                let image = images[0]
                guard image.data.count == (columns + delta) * 8 * (rows + delta - 1) * 16 * 4,
                    image.data.contains(where: { $0 != 0 }), renderer.nextUpdate == nil
                else { throw BenchmarkError.incomplete(received: index, expected: iterations) }
                bytes.append(Double(image.data.count))
                index += 1
            }
            return BenchmarkResult(
                name: name,
                context:
                    "\(nodes) nodes, \(nodes) directed edges, "
                    + "alternating \(columns)x\(rows)/\(columns + 1)x\(rows + 1) cells; "
                    + "8x16 pixels/cell, automatic labels; no terminal I/O; mounting excluded",
                metrics: [
                    .milliseconds("resize-layout-and-draw", samples: drawing),
                    BenchmarkMetric(name: "rgba-bytes", unit: "bytes", samples: bytes),
                ])
        }
    }
#endif
