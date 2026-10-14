import Testing

@testable import Twill

@Suite("Button interaction")
@MainActor
struct ButtonTests {
    @Test("Enter activates the focused button once without bubbling")
    func activation() {
        // -- Arrange --
        var activations = 0
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Button("Save") { activations += 1 }
                .onKeyPress { key in
                    parentKeys.append(key)
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.enter)

        // -- Assert --
        #expect(handled)
        #expect(activations == 1)
        #expect(parentKeys.isEmpty)
    }

    @Test("Other keys bubble without activating the button")
    func keyBubbling() {
        // -- Arrange --
        var activations = 0
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Button("Save") { activations += 1 }
                .onKeyPress { key in
                    parentKeys.append(key)
                    return key == .g ? .handled : .ignored
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.g)
        let ignored = renderer.handle(.space)

        // -- Assert --
        #expect(handled)
        #expect(!ignored)
        #expect(activations == 0)
        #expect(parentKeys == [.g, .space])
    }

    @Test("Custom labels are highlighted and arrows navigate between buttons")
    func focusNavigation() throws {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("Header")
                Button {
                    activated.append("First")
                } label: {
                    HStack(spacing: 1) {
                        Text("Open")
                        Text("note")
                    }
                }
                Button("Second") { activated.append("Second") }
            })
        let first = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        let moved = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let last = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(!first.isFocused(column: 0, row: 0))
        #expect(first.isFocused(column: 0, row: 1))
        #expect(first.isFocused(column: 5, row: 1))
        #expect(moved)
        #expect(activated == ["First", "Second"])
        #expect(!last.isFocused(column: 0, row: 1))
        #expect(last.isFocused(column: 0, row: 2))
    }
}
