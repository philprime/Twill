import Testing

@testable import Twill

@Suite("Control value formatting")
@MainActor
struct ControlValueFormattingTests {
    @Test("Slider formatting receives the actual external value without clamping it")
    func slider() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Slider("Level", value: .constant(1.25), in: 0...1, format: { "\($0 * 100)%" }).frame(width: 20))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText.contains("125.0%"))
    }

    @Test("Stepper formatting changes the display but not integer adjustment")
    func stepper() throws {
        // -- Arrange --
        var value = 2
        func view() -> some View {
            Stepper(
                "Count", value: Binding(get: { value }, set: { value = $0 }), in: 0...5,
                format: { "\($0) items" })
        }
        let renderer = ViewRenderer.make(view())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        renderer.update(view(), at: .now)
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(value == 3)
        #expect(grid.snapshotText.contains("Count: 3 items"))
    }
}
