import Testing

@testable import Twill

@Suite("Slider values and track")
@MainActor
struct SliderValueTests {
    @Test(
        "Track positions clamp external values without writing the binding",
        arguments: [
            (-1.0, "●───────"), (0, "●───────"), (0.25, "━━●─────"),
            (0.5, "━━━━●───"), (1, "━━━━━━━●"), (2, "━━━━━━━●"),
            (.infinity, "━━━━━━━●"), (-.infinity, "●───────"), (.nan, "●───────"),
        ])
    func track(value: Double, expected: String) throws {
        // -- Arrange --
        var writes = 0
        let renderer = ViewRenderer.make(Slider(value: Binding(get: { value }, set: { _ in writes += 1 })))

        // -- Act --
        let frame = renderer.render(.now, proposal: .init(width: 8))
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.snapshotText.split(separator: "\n")[1] == Substring(expected))
        #expect(writes == 0)
        #expect(frame.nextUpdate == nil)
    }

    @Test("A fixed range has a stationary thumb and does not rewrite the value")
    func fixedRange() throws {
        // -- Arrange --
        var writes = 0
        let renderer = ViewRenderer.make(
            Slider(value: Binding(get: { 4.0 }, set: { _ in writes += 1 }), in: 4...4) {
                HStack {
                    Text("Fixed")
                    Text("level")
                }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        for key in [KeyEvent.arrowLeft, .arrowRight, .home, .end] { _ = renderer.handle(key) }

        // -- Assert --
        #expect(grid.snapshotText == "Fixed level 4.0     \n●───────────────────")
        #expect(writes == 0)
    }

    @Test("Negative ranges normalize their track and arithmetic overflow clamps to finite bounds")
    func numericRanges() throws {
        // -- Arrange --
        let negative = ViewRenderer.make(Slider(value: Binding<Double>(get: { 0 }, set: { _ in }), in: -10...10))
        var value = Double.greatestFiniteMagnitude / 2
        let large = ViewRenderer.make(
            Slider(
                value: Binding(get: { value }, set: { value = $0 }), in: 0...Double.greatestFiniteMagnitude,
                step: Double.greatestFiniteMagnitude))
        _ = large.render(.now)

        // -- Act --
        let grid = try #require(negative.render(.now, proposal: .init(width: 8)).grid)
        _ = large.handle(.arrowRight)
        let upper = value
        _ = large.handle(.arrowLeft)

        // -- Assert --
        #expect(grid.snapshotText.split(separator: "\n")[1] == "━━━━●───")
        #expect(upper == Double.greatestFiniteMagnitude)
        #expect(value == 0)
    }

    @Test("The track has an intrinsic width, fills proposals, and handles tiny viewports")
    func sizing() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Slider(value: Binding<Double>(get: { 0.5 }, set: { _ in })))

        // -- Act --
        let intrinsic = try #require(renderer.render(.now).grid)
        let wide = try #require(renderer.drawFrame(proposal: .init(width: 30)))
        let single = try #require(renderer.drawFrame(proposal: .init(width: 1)))
        let empty = try #require(renderer.drawFrame(proposal: .init(width: 0, height: 0)))

        // -- Assert --
        #expect(intrinsic.size == CellSize(width: 20, height: 2))
        #expect(wide.size == CellSize(width: 30, height: 2))
        #expect(single.snapshotText == "0\n●")
        #expect(empty.size == .zero)
    }
}
