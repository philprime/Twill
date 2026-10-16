import Testing

@testable import Twill

@Suite("Stepper interaction")
@MainActor
struct StepperTests {
    @Test("Horizontal arrows adjust the live binding by the configured step without bubbling")
    func adjustment() throws {
        // -- Arrange --
        var value = 3
        var writes: [Int] = []
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Stepper(
                "Retries",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    }),
                in: 0...10, step: 2
            )
            .onKeyPress {
                parentKeys.append($0)
                return .handled
            })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        let increased = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        let decreased = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(increased && decreased)
        #expect(writes == [5, 7, 5])
        #expect(parentKeys.isEmpty)
        #expect(initial.snapshotText == "[-] Retries: 3 [+]")
        #expect(initial.isFocused(column: 0, row: 0))
        #expect(renderer.caretPosition == nil)
    }

    private struct BoundedCounter: View {
        @State private var value = 0
        let onWrite: @MainActor (Int) -> Void

        var body: some View {
            Stepper(
                "Count",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        onWrite($0)
                    }),
                in: 0...5, step: 3)
        }
    }

    @Test("Bounds clamp partial steps and unavailable directions do not rewrite the binding")
    func boundedAdjustments() throws {
        // -- Arrange --
        var writes: [Int] = []
        let renderer = ViewRenderer.make(BoundedCounter { writes.append($0) })
        let lower = try #require(renderer.render(.now).grid)

        // -- Act --
        let blockedLower = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        let upper = try #require(renderer.render(.now).grid)
        let blockedUpper = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(blockedLower && blockedUpper)
        #expect(lower.snapshotText == "(-) Count: 0 [+]")
        #expect(upper.snapshotText == "[-] Count: 5 (+)")
        #expect(writes == [3, 5, 2])
    }

    @Test("A single-value range disables both adjustments without changing the value")
    func fixedRange() throws {
        // -- Arrange --
        var writes = 0
        let renderer = ViewRenderer.make(
            Stepper(value: Binding(get: { 4 }, set: { _ in writes += 1 }), in: 4...4) {
                HStack {
                    Text("Worker")
                    Text("count")
                }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)

        // -- Assert --
        #expect(grid.snapshotText == "(-) Worker count: 4 (+)")
        #expect(writes == 0)
    }

    @Test("Unrelated and modified keys bubble while vertical arrows move focus")
    func focusAndRouting() throws {
        // -- Arrange --
        var value = 2
        var parentKeys: [KeyEvent] = []
        var activations = 0
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Stepper("Count", value: Binding(get: { value }, set: { value = $0 }), in: 0...4)
                Button("Done") { activations += 1 }
            }
            .onKeyPress { key in
                parentKeys.append(key)
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
        #expect(!blurred.isFocused(column: 0, row: 0))
        #expect(blurred.isFocused(column: 0, row: 1))
        #expect(activations == 1)
        #expect(value == 3)
        #expect(parentKeys == [modified, .enter, .arrowDown, .arrowUp])
    }
}
