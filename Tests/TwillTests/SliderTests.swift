import Testing

@testable import Twill

@Suite("Slider interaction")
@MainActor
struct SliderTests {
    @Test("Horizontal arrows adjust the live binding by the step without bubbling")
    func adjustment() throws {
        // -- Arrange --
        var value = 0.25
        var writes: [Double] = []
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Slider(
                "Volume",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    }),
                in: 0...1, step: 0.25
            )
            .onKeyPress {
                parentKeys.append($0)
                return .handled
            })
        let initial = try #require(renderer.render(.now, proposal: .init(width: 8)).grid)

        // -- Act --
        let increased = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        let decreased = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(increased && decreased)
        #expect(writes == [0.5, 0.75, 0.5])
        #expect(parentKeys.isEmpty)
        #expect(initial.snapshotText == "Volume 0\n━━●─────")
        #expect(initial.isFocused(column: 0, row: 1))
        #expect(renderer.caretPosition == nil)
    }

    @Test("Bounds clamp partial steps and Home/End reach the endpoints without duplicate writes")
    func boundedAdjustment() {
        // -- Arrange --
        var value = 0.0
        var writes: [Double] = []
        let renderer = ViewRenderer.make(
            Slider(
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    }),
                in: 0...1, step: 0.75))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.end)
        _ = renderer.handle(.end)
        _ = renderer.handle(.home)
        _ = renderer.handle(.home)

        // -- Assert --
        #expect(writes == [0.75, 1, 0.25, 1, 0])
    }

    @Test("Default keyboard increments are one percent of the range and support Float bindings")
    func defaultStep() {
        // -- Arrange --
        var value: Float = 5
        let renderer = ViewRenderer.make(Slider(value: Binding(get: { value }, set: { value = $0 }), in: 0...100))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(value == 6)
    }

    @Test("Unrelated and modified keys bubble while vertical arrows move focus")
    func focusAndRouting() throws {
        // -- Arrange --
        var value = 0.5
        var parentKeys: [KeyEvent] = []
        var activations = 0
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Slider(value: Binding(get: { value }, set: { value = $0 }), step: 0.25)
                Button("Done") { activations += 1 }
            }
            .onKeyPress {
                parentKeys.append($0)
                return .ignored
            })
        _ = renderer.render(.now)
        let modified = KeyEvent(.arrowRight, modifiers: [.control])

        // -- Act --
        let ignored = renderer.handle(modified)
        _ = renderer.handle(.enter)
        let moved = renderer.handle(.arrowDown)
        let blurred = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.arrowRight)

        // -- Assert --
        #expect(!ignored)
        #expect(moved)
        #expect(value == 0.75)
        #expect(activations == 1)
        #expect(!blurred.isFocused(column: 0, row: 1))
        #expect(blurred.isFocused(column: 0, row: 2))
        #expect(parentKeys == [modified, .enter, .arrowDown, .arrowUp])
    }
}
