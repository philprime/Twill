import Testing

@testable import Twill

@Suite("Scroll target viewport and presentation scopes")
@MainActor
struct ScrollTargetScopeTests {
    @Test("Only the nearest nested viewport scrolls, including clipped targets, without moving focus")
    func nestedViewports() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        var activated: [Int] = []
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<3, id: \.self) { id in Button("O\(id)") { activated.append(id) } }
                        ScrollView {
                            VStack(spacing: 0) { ForEach(10..<15, id: \.self) { Text("I\($0)") } }
                        }.frame(height: 2).id("inner")
                        Text("Tail")
                    }
                }.frame(height: 3)
            })
        let original = try #require(renderer.render(.now).grid)

        // -- Act --
        proxy?.scrollTo(14, anchor: .nearest)
        let clipped = try #require(renderer.drawFrame(proposal: .unspecified))
        proxy?.scrollTo("inner", anchor: .top)
        let revealed = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(clipped == original)
        #expect(revealed.snapshotText == "I13 \nI14 \nTail")
        #expect(activated == [0])
    }

    @Test("Inactive tab IDs do not mask targets in the selected tab")
    func selectedTab() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return TabView(selection: .constant(1)) {
                    Tab("Hidden", value: 0) {
                        ScrollView {
                            VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("H\($0)") } }
                        }.frame(height: 2)
                    }
                    Tab("Visible", value: 1) {
                        ScrollView {
                            VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("V\($0)") } }
                        }.frame(height: 2)
                    }
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo(4, anchor: .bottom)
        let grid = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(grid.snapshotText.contains("V3") && grid.snapshotText.contains("V4"))
        #expect(!grid.snapshotText.contains("V0"))
    }

    @Test("A presented modal's target wins over retained base IDs")
    func presentedModal() throws {
        // -- Arrange --
        var proxy: ScrollViewProxy?
        let renderer = ViewRenderer.make(
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("B\($0)") } }
                }.frame(height: 2).sheet(isPresented: .constant(true)) {
                    ScrollView {
                        VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("M\($0)") } }
                    }.frame(height: 2)
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        proxy?.scrollTo(4, anchor: .bottom)
        let grid = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(grid.snapshotText.contains("M3") && grid.snapshotText.contains("M4"))
        #expect(!grid.snapshotText.contains("M0"))
    }
}
