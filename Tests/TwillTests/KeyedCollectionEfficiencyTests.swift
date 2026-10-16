import Foundation
import Testing

@testable import Twill

@Suite("Keyed collection efficiency")
@MainActor
struct KeyedCollectionEfficiencyTests {
    @Test("Localized state work and keyed identity survive reorder and replacement", arguments: [24, 500])
    func reorderAndReplace(rowCount: Int) throws {
        // -- Arrange --
        let probe = Probe()
        let identifiers = Array(0..<rowCount)
        let date = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(Fixture(identifiers: identifiers, probe: probe))
        defer { renderer.unmount() }
        _ = renderer.render(date)

        // -- Act --
        try #require(probe.bindings[rowCount - 1]).wrappedValue = 1
        try #require(probe.bindings[rowCount - 2]).wrappedValue = 2
        _ = renderer.render(date)
        let localizedEvaluations = probe.evaluations
        renderer.update(Fixture(identifiers: Array(identifiers.reversed()), probe: probe), at: date)
        let reordered = try #require(renderer.render(date).grid)
        let replacedIDs = [rowCount] + Array(identifiers.reversed().dropFirst())
        renderer.update(Fixture(identifiers: replacedIDs, probe: probe), at: date)
        let replaced = try #require(renderer.render(date).grid)
        let settledEvaluations = probe.evaluations
        let unchanged = renderer.render(date)

        // -- Assert --
        #expect(localizedEvaluations == rowCount + 2)
        #expect(reordered.snapshotText.hasPrefix("\(rowCount - 1):1"))
        #expect(replaced.snapshotText.hasPrefix("\(rowCount):0"))
        #expect(replaced.snapshotText.contains("\(rowCount - 2):2"))
        #expect(unchanged.grid == replaced)
        #expect(unchanged.nextUpdate == nil)
        #expect(probe.evaluations == settledEvaluations)
    }

    private final class Probe {
        var evaluations = 0
        var bindings: [Int: Binding<Int>] = [:]
    }

    private struct Fixture: View {
        let identifiers: [Int]
        let probe: Probe

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(identifiers, id: \.self) { identifier in
                        Row(identifier: identifier, probe: probe)
                    }
                }
            }
            .frame(width: 20, height: 4, alignment: .topLeading)
        }
    }

    private struct Row: View {
        @State private var count = 0
        let identifier: Int
        let probe: Probe

        var body: some View {
            probe.evaluations += 1
            probe.bindings[identifier] = $count
            return Text("\(identifier):\(count)")
        }
    }
}
