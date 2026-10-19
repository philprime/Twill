import Testing

@testable import Twill

@Suite("Mixed frame constraints")
@MainActor
struct FrameConstraintTests {
    @Test("Fixed and flexible dimensions combine in either axis")
    func mixedAxes() throws {
        // -- Arrange --
        let fixedWidth = ViewRenderer.make(Text("X").frame(width: 4, maxHeight: .infinity, alignment: .bottomTrailing))
        let fixedHeight = ViewRenderer.make(Text("Y").frame(height: 2, maxWidth: .infinity, alignment: .bottomTrailing))

        // -- Act --
        let vertical = try #require(fixedWidth.render(.now, proposal: .init(width: 8, height: 3)).grid)
        let horizontal = try #require(fixedHeight.render(.now, proposal: .init(width: 8, height: 5)).grid)

        // -- Assert --
        #expect(vertical.size == CellSize(width: 4, height: 3))
        #expect(vertical[3, 2] == .glyph("X", width: 1))
        #expect(horizontal.size == CellSize(width: 8, height: 2))
        #expect(horizontal[7, 1] == .glyph("Y", width: 1))
    }

    @Test("Minimum-only frames pad intrinsic content without demanding the whole proposal")
    func minimumDimensions() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("X").frame(minWidth: 4, minHeight: 3, alignment: .bottomTrailing))

        // -- Act --
        let intrinsic = try #require(renderer.render(.now).grid)
        let offered = try #require(renderer.drawFrame(proposal: .init(width: 10, height: 8)))
        let clipped = try #require(renderer.drawFrame(proposal: .init(width: 2, height: 1)))

        // -- Assert --
        #expect(intrinsic.size == CellSize(width: 4, height: 3))
        #expect(intrinsic[3, 2] == .glyph("X", width: 1))
        #expect(offered == intrinsic)
        #expect(clipped.snapshotText == " X")
    }

    @Test("Runtime integer limits and minimums bound finite and unspecified proposals")
    func runtimeBounds() throws {
        // -- Arrange --
        let minimum = 3
        let maximum = 6
        let renderer = ViewRenderer.make(
            Text("X").frame(
                minWidth: minimum, maxWidth: .cells(maximum),
                minHeight: 2, maxHeight: 4, alignment: .bottomTrailing))

        // -- Act --
        let finite = try #require(renderer.render(.now, proposal: .init(width: 10, height: 8)).grid)
        let natural = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(finite.size == CellSize(width: 6, height: 4))
        #expect(finite[5, 3] == .glyph("X", width: 1))
        #expect(natural.size == CellSize(width: 3, height: 2))
        #expect(natural[2, 1] == .glyph("X", width: 1))
    }

    @Test("One modifier resolves empty calls and permits zero-sized constraints")
    func emptyAndZero() {
        // -- Arrange --
        let empty = ViewRenderer.make(Text("X").frame())
        let zero = ViewRenderer.make(Text("X").frame(width: 0, minHeight: 0, maxHeight: 0))

        // -- Act --
        let natural = empty.render(.now)
        let clipped = zero.render(.now)

        // -- Assert --
        #expect(natural.grid?.snapshotText == "X")
        #expect(clipped.grid?.size == .zero)
    }

    @Test("The boundary validator rejects negative or contradictory same-axis constraints")
    func validation() {
        // -- Arrange --
        let valid = FrameAxisConstraints.isValid(fixed: 3, minimum: 2, maximum: .cells(4))
        let zero = FrameAxisConstraints.isValid(fixed: 0, minimum: 0, maximum: .cells(0))

        // -- Act --
        let invalid = [
            FrameAxisConstraints.isValid(fixed: -1),
            FrameAxisConstraints.isValid(minimum: -1),
            FrameAxisConstraints.isValid(maximum: .cells(-1)),
            FrameAxisConstraints.isValid(minimum: 3, maximum: .cells(2)),
            FrameAxisConstraints.isValid(fixed: 2, minimum: 3),
            FrameAxisConstraints.isValid(fixed: 3, maximum: .cells(2)),
        ]

        // -- Assert --
        #expect(valid && zero)
        #expect(invalid.allSatisfy { !$0 })
    }

    @Test("Cached resize keeps frame constraints without reevaluating bodies")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        let wide = try #require(renderer.render(.now, proposal: .init(width: 8, height: 4)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 2, height: 1)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 8, height: 4)))

        // -- Assert --
        #expect(wide.size == CellSize(width: 4, height: 4))
        #expect(narrow.size == CellSize(width: 2, height: 1))
        #expect(restored == wide)
        #expect(evaluations == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Text("X").frame(width: 4, minHeight: 2, maxHeight: .infinity)
        }
    }
}
