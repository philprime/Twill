import Testing

@testable import Twill

@Suite("Text field editing")
@MainActor
struct TextFieldTests {
    @Test("Editing keys stay in the field until Enter restores arrow navigation")
    func editingNavigation() throws {
        // -- Arrange --
        var activations = 0
        let renderer = ViewRenderer.make(NavigationFixture(onActivate: { activations += 1 }))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.a)
        _ = renderer.render(.now)
        _ = renderer.handle(.character("界"))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.backspace)
        let editing = try #require(renderer.render(.now).grid)
        let tabConsumed = renderer.handle(.tab)
        let downConsumed = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(initial.snapshotText == "Name Next")
        #expect(editing.snapshotText == "界 Next")
        #expect(editing.isFocused(column: 0, row: 0))
        #expect(tabConsumed)
        #expect(downConsumed)
        #expect(activations == 1)
    }

    @Test("Navigation shortcuts give way to bound editing until Escape")
    func editingModes() throws {
        // -- Arrange --
        var shortcuts: [String] = []
        let renderer = ViewRenderer.make(SearchFixture(onShortcut: { shortcuts.append($0) }))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.questionMark)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        let inserted = renderer.handle(.questionMark)
        let editing = try #require(renderer.render(.now).grid)
        let endedEditing = renderer.handle(.escape)
        _ = renderer.render(.now)
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(initial.snapshotText == "ab")
        #expect(initial.isFocused(column: 0, row: 0))
        #expect(inserted)
        #expect(editing.snapshotText == "a?b")
        #expect(endedEditing)
        #expect(shortcuts == ["question:ab", "escape:a?b"])
    }
}

@MainActor
private struct NavigationFixture: View {
    @State private var text = ""
    let onActivate: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 1) {
            TextField("Name", text: $text)
            Text("Next").focusable().onKeyPress { key in
                guard key == .enter else { return .ignored }
                onActivate()
                return .handled
            }
        }
    }
}

@MainActor
private struct SearchFixture: View {
    @State private var text = "ab"
    let onShortcut: @MainActor (String) -> Void

    var body: some View {
        TextField("Search", text: $text)
            .onKeyPress { key in
                switch key {
                case .questionMark: onShortcut("question:\(text)")
                case .escape: onShortcut("escape:\(text)")
                default: return .ignored
                }
                return .handled
            }
    }
}
