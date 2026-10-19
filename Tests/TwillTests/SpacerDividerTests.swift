import Testing

@testable import Twill

@Suite("Spacer and Divider layout")
@MainActor
struct SpacerDividerTests {
    @Test("Horizontal spacers consume surplus after stack gaps")
    func horizontalSpace() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 1) {
                Text("A")
                Spacer()
                Text("B")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 12)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "A          B")
    }

    @Test("Multiple spacer minimums reserve space before dividing surplus")
    func minimums() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Spacer(minLength: 3)
                Text("M")
                Spacer(minLength: 1)
                Text("B")
            })

        // -- Act --
        let natural = try #require(renderer.render(.now).grid)
        let wide = try #require(renderer.drawFrame(proposal: .init(width: 9)))
        let scarce = try #require(renderer.drawFrame(proposal: .init(width: 4)))

        // -- Assert --
        #expect(natural.snapshotText == "A   M B")
        #expect(wide.snapshotText == "A    M  B")
        #expect(scarce.snapshotText == "A   ")
    }

    @Test("Vertical spacers consume height rather than width")
    func verticalSpace() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading, spacing: 0) {
                Text("Top")
                Spacer(minLength: 1)
                Text("Bottom")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(height: 5)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Top   \n      \n      \n      \nBottom")
    }

    @Test("In-stack spacer backgrounds cover allocated space without changing fill intent")
    func spacerAppearance() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Spacer().backgroundStyle(Color.red)
                Text("B")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 6)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "A    B")
        #expect(grid.background(column: 3, row: 0) == .red)
    }

    @Test("Standalone spacers expand on both axes without drawing or scheduling")
    func standaloneSpace() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Spacer().backgroundStyle(Color.red))

        // -- Act --
        let frame = renderer.render(.now, proposal: .init(width: 4, height: 2))
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 4, height: 2))
        #expect(grid.background(column: 3, row: 1) == .red)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Automatic dividers span intrinsic multiline neighbors in either stack")
    func dividers() throws {
        // -- Arrange --
        let horizontal = ViewRenderer.make(
            HStack(spacing: 1) {
                Text("ab\nc")
                Divider()
                Text("z")
            })
        let vertical = ViewRenderer.make(
            VStack(alignment: .leading, spacing: 0) {
                Text("abc")
                Divider()
                Text("z")
            })

        // -- Act --
        let horizontalGrid = try #require(horizontal.render(.now).grid)
        let verticalGrid = try #require(vertical.render(.now).grid)

        // -- Assert --
        #expect(horizontalGrid.snapshotText == "ab │ z\nc  │  ")
        #expect(verticalGrid.snapshotText == "abc\n───\nz  ")
    }

    @Test("Explicit divider direction and inherited appearance work outside a stack")
    func explicitDivider() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Divider(.vertical).foregroundStyle(Color.red).bold())

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 8, height: 3)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "│\n│\n│")
        #expect(grid.foreground(column: 0, row: 2) == .red)
        #expect(grid.attributes(column: 0, row: 2).contains(.bold))
    }

    @Test("Cached resize updates space and divider extent without reevaluating bodies")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        let wide = try #require(renderer.render(.now, proposal: .init(width: 12)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 6)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 12)))

        // -- Assert --
        #expect(wide.snapshotText == "A         │B")
        #expect(narrow.snapshotText == "A   │B")
        #expect(restored == wide)
        #expect(evaluations == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return HStack(spacing: 0) {
                Text("A")
                Spacer()
                Divider()
                Text("B")
            }
        }
    }

    @Test("Stack direction passes through modifiers and changes at nested stacks")
    func nestedAxes() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(alignment: .top, spacing: 0) {
                Text("L")
                Spacer(minLength: 2).foregroundStyle(Color.red)
                VStack(spacing: 0) {
                    Text("T")
                    Spacer(minLength: 1)
                    Text("B")
                }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 6, height: 3)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "L    T\n      \n     B")
    }
}
