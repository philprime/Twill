import Testing

@testable import Twill

@Suite("Pane-oriented split layout")
@MainActor
struct SplitViewTests {
    @Test("Fixed and flexible panes share finite space and use intrinsic width without a proposal")
    func allocation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            SplitView(leadingWidth: .fixed(3), trailingWidth: .flexible(minimum: 2), spacing: 1) {
                Text("L")
            } trailing: {
                Text("R")
            })

        // -- Act --
        let wide = try #require(renderer.render(.now, proposal: .init(width: 10, height: 2)).grid)
        let natural = try #require(renderer.drawFrame(proposal: .unspecified))
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 4)))

        // -- Assert --
        #expect(wide.snapshotText == "L   R     \n          ")
        #expect(natural.snapshotText == "L   R ")
        #expect(narrow.snapshotText == "L   ")
    }

    @Test("Two flexible panes reserve minimums before sharing surplus")
    func flexibleMinimums() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            SplitView(
                leadingWidth: .flexible(minimum: 2),
                trailingWidth: .flexible(minimum: 4), spacing: 2
            ) {
                Text("A")
            } trailing: {
                Text("B")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 10)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "A    B    ")
    }

    @Test("Finite flexible sharing does not depend on coincidental intrinsic widths")
    func stableFlexibleSharing() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            SplitView(spacing: 0) {
                Text("abcdefghij")
            } trailing: {
                Text("x")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 11)).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 11, height: 2))
        #expect(grid[5, 0] == .glyph("x", width: 1))
    }

    @Test("An absent leading pane does not reserve its width or a gap")
    func emptyPane() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            SplitView(
                leadingWidth: .fixed(7),
                trailingWidth: .flexible(minimum: 2), spacing: 3
            ) {
                EmptyView()
            } trailing: {
                Text("R")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 8)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "R       ")
    }

    @Test("Transparent content remains within its assigned pane")
    func transparentContent() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            SplitView(leadingWidth: .fixed(3), spacing: 1) {
                Group {
                    Text("A")
                    Text("B")
                }
            } trailing: {
                Text("C")
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 6)).grid)

        // -- Assert --
        #expect(grid.snapshotText == "AB  C ")
    }

    @Test("Removing a pane retains the other pane's state and focused control")
    func retainedFocus() throws {
        // -- Arrange --
        func content(_ showLeading: Bool) -> some View {
            SplitView(leadingWidth: .fixed(3)) {
                if showLeading { Button("L") {} }
            } trailing: {
                Counter()
            }
        }
        let renderer = ViewRenderer.make(content(true))
        _ = renderer.render(.now, proposal: .init(width: 10))
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now, proposal: .init(width: 10))

        // -- Act --
        renderer.update(content(false), at: .now)
        _ = renderer.render(.now, proposal: .init(width: 10))
        _ = renderer.handle(.enter)
        let grid = try #require(renderer.render(.now, proposal: .init(width: 10)).grid)

        // -- Assert --
        #expect(grid.snapshotText.contains("R:2"))
        #expect(!grid.snapshotText.contains("L"))
    }

    @Test("Nested reader viewports keep independent offsets")
    func nestedScrolling() throws {
        // -- Arrange --
        var right: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            SplitView(leadingWidth: .fixed(3), spacing: 1) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { ForEach(0..<5, id: \.self) { Text("L\($0)") } }
                }
            } trailing: {
                ScrollViewReader { supplied in
                    right = supplied
                    return ScrollView {
                        VStack(alignment: .leading, spacing: 0) { ForEach(0..<5, id: \.self) { Text("R\($0)") } }
                    }
                }
            })
        _ = renderer.render(.now, proposal: .init(width: 7, height: 2))

        // -- Act --
        right?.scrollTo(4, anchor: .bottom)
        let grid = try #require(renderer.drawFrame(proposal: .init(width: 7, height: 2)))

        // -- Assert --
        #expect(grid.snapshotText == "L0  R3 \nL1  R4 ")
    }

    @Test("Removing the focused pane falls back to the remaining control")
    func removedFocus() {
        // -- Arrange --
        var actions: [Int] = []
        func content(_ showLeading: Bool) -> some View {
            SplitView {
                if showLeading { Button("L") { actions.append(1) } }
            } trailing: {
                Button("R") { actions.append(2) }
            }
        }
        let renderer = ViewRenderer.make(content(true))
        _ = renderer.render(.now, proposal: .init(width: 8))

        // -- Act --
        renderer.update(content(false), at: .now)
        _ = renderer.render(.now, proposal: .init(width: 8))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == [2])
    }

    @Test("Resize updates pane allocation without reevaluating the body")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        let wide = try #require(renderer.render(.now, proposal: .init(width: 10)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 6)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 10)))

        // -- Assert --
        #expect(wide.size.width == 10 && narrow.size.width == 6)
        #expect(restored == wide)
        #expect(evaluations == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return SplitView(leadingWidth: .fixed(3)) {
                Text("L")
            } trailing: {
                Text("R")
            }
        }
    }

    private struct Counter: View {
        @State private var count = 0
        var body: some View { Button("R:\(count)") { count += 1 } }
    }
}
