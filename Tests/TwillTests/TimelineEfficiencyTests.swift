import Foundation
import Testing

@testable import Twill

@Suite("Timeline efficiency")
@MainActor
struct TimelineEfficiencyTests {
    @Test("Many due siblings skip missed periods without rebuilding a static sibling", arguments: [24, 500])
    func skippedPeriods(siblingCount: Int) {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let skipped = start.addingTimeInterval(1_000_000)
        var evaluations = Array(repeating: 0, count: siblingCount)
        var staticBodies = 0
        let renderer = ViewRenderer.make(
            VStack {
                StaticProbe { staticBodies += 1 }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<siblingCount, id: \.self) { index in
                            TimelineView(.periodic(from: start, by: Double(index + 1))) { _ -> Text in
                                evaluations[index] += 1
                                return Text("Clock \(index)")
                            }
                        }
                    }
                }
                .frame(width: 40, height: 4)
            })
        defer { renderer.unmount() }
        _ = renderer.render(start)

        // -- Act --
        renderer.refreshContent(at: skipped)
        _ = renderer.drawFrame(proposal: ProposedCellSize(width: 80, height: 24))
        renderer.refreshContent(at: skipped)
        _ = renderer.drawFrame(proposal: ProposedCellSize(width: 60, height: 20))

        // -- Assert --
        #expect(evaluations.allSatisfy { $0 == 2 })
        #expect(staticBodies == 1)
        #expect(renderer.nextUpdate == skipped.addingTimeInterval(1))
    }

    private struct StaticProbe: View {
        let onBody: @MainActor () -> Void

        var body: some View {
            onBody()
            return Text("Static")
        }
    }
}
