import Foundation
import Synchronization
import Testing

@testable import Twill

@Suite("Rendering efficiency")
@MainActor
struct RenderingEfficiencyTests {
    @Test("Focus requests are evaluated once along a nested path", arguments: [0, 1, 2])
    func focusRequestTraversal(depth: Int) throws {
        // -- Arrange --
        var reads = 0
        var focused = true
        let binding = FocusState<Bool>.Binding(
            get: {
                reads += 1
                return focused
            }, set: { focused = $0 })
        let renderer = ViewRenderer.make(NestedFocus(depth: depth, binding: binding))
        renderer.refreshContent(at: .now)
        reads = 0

        // -- Act --
        let target = renderer.focusTarget()

        // -- Assert --
        #expect(target != nil)
        #expect(reads <= 2)
    }

    @Test("A nested flexible child is measured once per layout pass", arguments: [1, 2, 3])
    func nestedFlexibleLayout(depth: Int) throws {
        // -- Arrange --
        let counter = MeasurementCounter()
        let renderer = ViewRenderer.make(
            VStack {
                Text("Header")
                NestedLayout(depth: depth, counter: counter)
                Text("Footer")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 80, height: 24))

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 80, height: 24))
        #expect(counter.value.withLock { $0 } == 1)
    }

    @Test("Table cell measurement stays linear in row count", arguments: [1, 100, 500])
    func tableMeasurementCount(rowCount: Int) {
        // -- Arrange --
        let counter = MeasurementCounter()
        let rows = (0..<rowCount).map { TableRecord(id: $0) }
        let renderer = ViewRenderer.make(
            VStack {
                Text("Header")
                Table(rows, selection: Binding<Int?>(get: { nil }, set: { _ in })) {
                    TableColumn("Measured") { _ in MeasurementView(counter: counter) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 80, height: 24))

        // -- Assert --
        #expect(counter.value.withLock { $0 } <= rowCount * 2)
        #expect(frame.grid?.size == CellSize(width: 80, height: 24))
        #expect(frame.nextUpdate == nil)
    }

    private struct TableRecord: Identifiable {
        let id: Int
    }

    @Test("Offscreen canvases are not drawn but become drawable after scrolling")
    func clippedDrawing() {
        // -- Arrange --
        var draws = [0, 0]
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack(spacing: 0) {
                    Canvas { _, _ in draws[0] += 1 }.frame(height: 1)
                    Canvas { _, _ in draws[1] += 1 }.frame(height: 1)
                }
            }.frame(width: 10, height: 1))

        // -- Act --
        _ = renderer.render(.now)
        let initial = draws
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(initial == [1, 0])
        #expect(draws == [1, 1])
    }

    @Test("Stateless mounted views are reflected only when first mounted")
    func statelessReconciliation() {
        // -- Arrange --
        let counter = MeasurementCounter()
        let renderer = ViewRenderer.make(StatelessFixture(counter: counter, text: "Initial"))
        renderer.refreshContent(at: .now)

        // -- Act --
        renderer.update(StatelessFixture(counter: counter, text: "First"), at: .now)
        renderer.update(StatelessFixture(counter: counter, text: "Final"), at: .now)
        let grid = renderer.drawFrame(proposal: .unspecified)

        // -- Assert --
        #expect(counter.value.withLock { $0 } == 1)
        #expect(grid?.snapshotText == "Final")
    }

    private struct StatelessFixture: View, CustomReflectable {
        let counter: MeasurementCounter
        let text: String
        var body: some View { Text(text) }

        nonisolated var customMirror: Mirror {
            counter.value.withLock { $0 += 1 }
            return Mirror(self, children: [:])
        }
    }

    private struct NestedFocus: View {
        let depth: Int
        let binding: FocusState<Bool>.Binding

        @ViewBuilder var body: some View {
            if depth == 0 {
                Text("Target").focusable().focused(binding)
            } else {
                VStack { NestedFocus(depth: depth - 1, binding: binding) }
            }
        }
    }

    private struct NestedLayout: View {
        let depth: Int
        let counter: MeasurementCounter

        @ViewBuilder var body: some View {
            if depth == 0 {
                MeasurementView(counter: counter)
            } else {
                VStack {
                    HStack { NestedLayout(depth: depth - 1, counter: counter) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private struct MeasurementView: View, PrimitiveView {
        typealias Body = Never
        let counter: MeasurementCounter

        func makeDescription() -> ViewDescription { .drawing(MeasurementDrawing(counter: counter)) }
    }

    private nonisolated final class MeasurementCounter: Sendable {
        let value = Mutex(0)
    }

    private nonisolated struct MeasurementDrawing: PrimitiveDrawing {
        let counter: MeasurementCounter

        func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
            counter.value.withLock { $0 += 1 }
            return CellSize(width: 1, height: 1)
        }

        func draw(in context: inout DrawingContext) {}
    }
}
