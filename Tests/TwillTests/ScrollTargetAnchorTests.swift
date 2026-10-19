import Testing

@testable import Twill

@Suite("Scoped scroll targets and anchors")
@MainActor
struct ScrollTargetAnchorTests {
    @Test("Explicit identity outside ForEach supports center and nearest anchors")
    func explicitTarget() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<5, id: \.self) { Text("Row \($0)") }
                        Text("Target").id("target")
                        ForEach(6..<10, id: \.self) { Text("Row \($0)") }
                    }
                }.frame(height: 3)
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo("target", anchor: .center)
        let centered = try #require(renderer.drawFrame(proposal: .unspecified))
        proxy?.scrollTo("target", anchor: .nearest)
        let unchanged = try #require(renderer.drawFrame(proposal: .unspecified))
        proxy?.scrollTo(0)
        _ = renderer.drawFrame(proposal: .unspecified)
        proxy?.scrollTo("target", anchor: .nearest)
        let nearest = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(centered.snapshotText == "Row 4 \nTarget\nRow 6 ")
        #expect(unchanged == centered)
        #expect(nearest.snapshotText == "Row 3 \nRow 4 \nTarget")
    }

    @Test("A transparent group identity targets the union of its layout items")
    func compoundTarget() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { Text("\($0)") }
                        Group {
                            Text("A")
                            Text("B")
                            Text("C")
                        }.id("block")
                        ForEach(5..<9, id: \.self) { Text("\($0)") }
                    }
                }.frame(height: 3)
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo("block", anchor: .bottom)
        let grid = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(grid.snapshotText == "A\nB\nC")
    }

    @Test("Nearest preserves a viewport inside an oversized target and moves only to its nearest edge")
    func oversizedTarget() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("S")
                        Text("A\nB\nC\nD\nE\nF").id("large")
                        Text("T").id("tail")
                    }
                }.frame(height: 3)
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo("large", anchor: .center)
        let middle = try #require(renderer.drawFrame(proposal: .unspecified))
        proxy?.scrollTo("large", anchor: .nearest)
        let retained = try #require(renderer.drawFrame(proposal: .unspecified))
        proxy?.scrollTo("tail", anchor: .bottom)
        _ = renderer.drawFrame(proposal: .unspecified)
        proxy?.scrollTo("large", anchor: .nearest)
        let nearest = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(middle.snapshotText == "B\nC\nD")
        #expect(retained == middle)
        #expect(nearest.snapshotText == "D\nE\nF")
    }

    @Test("Independent nested readers reuse IDs without stealing one another's targets")
    func readerScopes() throws {
        // -- Arrange --
        var outer: ScrollViewProxy?
        var inner: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                outer = supplied
                return HStack(spacing: 1) {
                    ScrollViewReader { nested in
                        inner = nested
                        return ScrollView {
                            VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("L\($0)") } }
                        }.frame(height: 2)
                    }
                    ScrollView {
                        VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("R\($0)") } }
                    }.frame(height: 2)
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        outer?.scrollTo(4, anchor: .bottom)
        let right = try #require(renderer.drawFrame(proposal: .unspecified))
        inner?.scrollTo(4, anchor: .bottom)
        let both = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(right.snapshotText == "L0 R3\nL1 R4")
        #expect(both.snapshotText == "L3 R3\nL4 R4")
    }

    @Test("An unscrollable duplicate ID cannot mask a measured scroll target")
    func skipUnscrollableTarget() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return VStack(alignment: .leading, spacing: 0) {
                    Text("X").id(4)
                    ScrollView {
                        VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("\($0)") } }
                    }.frame(height: 2)
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo(4, anchor: .bottom)
        let grid = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(grid.snapshotText == "X\n3\n4")
    }

    @Test("Missing and removed targets do not invalidate or scroll")
    func missingTargets() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        func content(_ ids: [Int]) -> some View {
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(spacing: 0) { ForEach(ids, id: \.self) { Text("\($0)") } }
                }.frame(height: 2)
            }
        }
        let renderer = ViewRenderer.make(content(Array(0..<5)))
        _ = renderer.render(.now)
        renderer.update(content([0, 1, 2, 3]), at: .now)
        let before = try #require(renderer.render(.now).grid)
        var invalidations = 0
        renderer.onInvalidation = { invalidations += 1 }

        // -- Act --
        proxy?.scrollTo(4, anchor: .nearest)
        proxy?.scrollTo(99, anchor: .center)
        let after = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(after == before)
        #expect(invalidations == 0)
    }
}
