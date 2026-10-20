import Testing

@testable import Twill

@Suite("Cell scroll indicators")
@MainActor
struct ScrollIndicatorTests {
    @Test("Hidden mode keeps all columns while visible mode reserves one")
    func visibility() throws {
        // -- Arrange --
        func content(_ visibility: ScrollIndicatorVisibility) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { ForEach(0..<6, id: \.self) { Text("\($0)") } }
            }.scrollIndicators(visibility).frame(width: 3, height: 3, alignment: .topLeading)
        }
        let hidden = ViewRenderer.make(content(.hidden))
        let visible = ViewRenderer.make(content(.visible))

        // -- Act --
        let ordinary = try #require(hidden.render(.now).grid)
        let indicated = try #require(visible.render(.now).grid)
        _ = visible.handle(.pageDown)
        let bottom = try #require(visible.render(.now).grid)

        // -- Assert --
        #expect(ordinary.snapshotText == "0  \n1  \n2  ")
        #expect(indicated.snapshotText == "0 █\n1 │\n2 │")
        #expect(bottom.snapshotText == "3 │\n4 │\n5 █")
    }

    @Test("Fitting and empty content keep the reserved track with a full thumb")
    func fittingContent() throws {
        // -- Arrange --
        let fitting = ViewRenderer.make(ScrollView { Text("AB") }.scrollIndicators(.visible))
        let empty = ViewRenderer.make(ScrollView { EmptyView() }.scrollIndicators(.visible))

        // -- Act --
        let text = try #require(fitting.render(.now, proposal: .init(width: 4, height: 3)).grid)
        let blank = try #require(empty.render(.now, proposal: .init(width: 2, height: 3)).grid)

        // -- Assert --
        #expect(text.snapshotText == "AB █\n   █\n   █")
        #expect(blank.snapshotText == " █\n █\n █")
    }

    @Test("One-column and zero-size viewports remain valid")
    func tinyViewports() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(ScrollView { Text("ABCD") }.scrollIndicators(.visible))

        // -- Act --
        let narrow = try #require(renderer.render(.now, proposal: .init(width: 1, height: 2)).grid)
        let zero = try #require(renderer.drawFrame(proposal: .init(width: 0, height: 0)))

        // -- Assert --
        #expect(narrow.snapshotText == "█\n█")
        #expect(zero.size == .zero)
    }

    @Test("Nested hidden settings override inherited visibility")
    func inheritedOverride() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(ScrollView { Text("X") }.scrollIndicators(.hidden).scrollIndicators(.visible))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "X")
    }

    @Test("Table headers and rows share the indicator-adjusted content width")
    func tableGeometry() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Table([1], id: \.self) {
                TableColumn("A") { _ in Text("abcd") }.width(.flexible(minimum: 1))
                TableColumn("B") { _ in Text("x") }.width(1)
            }.scrollIndicators(.visible))

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 8, height: 3)).grid)

        // -- Assert --
        #expect(grid[6, 0] == .glyph("B", width: 1))
        #expect(grid[6, 1] == .glyph("x", width: 1))
        #expect(grid[7, 2] == .glyph("█", width: 1))
    }

    @Test("List indicators follow anchored offsets without moving selection or activation focus")
    func listAnchors() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        var activated: [Int] = []
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return List(Array(0..<6), id: \.self, selection: .constant(nil)) { Text("\($0)") }
                    .onActivate { activated.append($0) }
                    .scrollIndicators(.visible).frame(width: 3, height: 3)
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo(5, anchor: .bottom)
        let bottom = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(bottom.snapshotText == "3 │\n4 │\n5 █")
        #expect(activated == [0])
    }

    @Test("Cached resize reflows content without reevaluating bodies and indicators inherit appearance")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }).foregroundStyle(Color.red).bold())
        let wide = try #require(renderer.render(.now, proposal: .init(width: 4, height: 2)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 2, height: 2)))

        // -- Assert --
        #expect(wide.snapshotText == "ABC█\nD  █")
        #expect(narrow.snapshotText == "A█\nB│")
        #expect(narrow.foreground(column: 1, row: 1) == .red)
        #expect(narrow.attributes(column: 1, row: 1).contains(.bold))
        #expect(evaluations == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return ScrollView { Text("ABCD") }.scrollIndicators(.visible)
        }
    }
}
