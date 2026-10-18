import Synchronization
import Testing

@testable import Twill

@Suite("Layout measurement contract")
@MainActor
struct LayoutContractTests {
    private final class Measurements: Sendable {
        let proposals = Mutex<[(width: Int?, height: Int?)]>([])
    }

    private struct MeasuredText: View, PrimitiveView {
        typealias Body = Never
        let measurements: Measurements

        func makeDescription() -> ViewDescription {
            .drawing(Drawing(measurements: measurements))
        }

        private struct Drawing: PrimitiveDrawing {
            let measurements: Measurements

            func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
                measurements.proposals.withLock { $0.append((proposal.width, proposal.height)) }
                return TextDrawing("ABCDE").sizeThatFits(proposal)
            }

            func draw(in context: inout DrawingContext) {
                TextDrawing("ABCDE").draw(in: &context)
            }
        }
    }

    private struct OffsetLayout: PrimitiveLayout {
        func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
            subviews.map { $0.sizeThatFits(ProposedCellSize(width: 3, height: 1)) }
        }

        func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
            let child = subviews.first ?? .zero
            return proposal.constrain(CellSize(width: child.width + 2, height: child.height + 1))
        }

        func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
            subviews.map { CellRect(column: 2, row: 1, width: $0.width, height: $0.height) }
        }
    }

    private struct LayoutFixture: View, PrimitiveView {
        typealias Body = Never
        let measurements: Measurements

        func makeDescription() -> ViewDescription {
            .group(children: [MeasuredText(measurements: measurements)], layout: OffsetLayout())
        }
    }

    @Test("An unfamiliar layout controls child proposals and placement without renderer dispatch")
    func customChildMeasurement() throws {
        // -- Arrange --
        let measurements = Measurements()
        let renderer = ViewRenderer.make(LayoutFixture(measurements: measurements))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: ProposedCellSize(width: 9, height: 4)).grid)
        let proposals = measurements.proposals.withLock { $0 }

        // -- Assert --
        #expect(proposals.count == 1)
        #expect(proposals.first?.width == 3)
        #expect(proposals.first?.height == 1)
        #expect(frame.size == CellSize(width: 5, height: 2))
        #expect(frame.snapshotText == "     \n  ABC")
    }
}
