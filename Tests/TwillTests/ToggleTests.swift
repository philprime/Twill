import Testing

@testable import Twill

@Suite("Toggle interaction")
@MainActor
struct ToggleTests {
    @Test("Space writes the inverse binding value once without bubbling")
    func activation() throws {
        // -- Arrange --
        var value = false
        var writes: [Bool] = []
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Toggle(
                "Notifications",
                isOn: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    })
            )
            .onKeyPress { key in
                parentKeys.append(key)
                return .handled
            })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        let handled = renderer.handle(.space)
        _ = renderer.handle(.space)

        // -- Assert --
        #expect(handled)
        #expect(writes == [true, false])
        #expect(parentKeys.isEmpty)
        #expect(initial.snapshotText == "[ ] Notifications")
        #expect(!value)
    }

    @Test("Other keys including modified Space bubble without changing the value")
    func keyBubbling() {
        // -- Arrange --
        var value = true
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Toggle("Notifications", isOn: Binding(get: { value }, set: { value = $0 }))
                .onKeyPress { key in
                    parentKeys.append(key)
                    return key == .g ? .handled : .ignored
                })
        _ = renderer.render(.now)
        let modifiedSpace = KeyEvent(.character(" "), modifiers: .control)

        // -- Act --
        let handled = renderer.handle(.g)
        let ignored = renderer.handle(.enter)
        let modified = renderer.handle(modifiedSpace)

        // -- Assert --
        #expect(handled)
        #expect(!ignored)
        #expect(!modified)
        #expect(value)
        #expect(parentKeys == [.g, .enter, modifiedSpace])
    }

    @Test("Moving focus preserves checkbox values and activates only the focused toggle")
    func focusNavigation() throws {
        // -- Arrange --
        var firstValue = true
        var secondValue = false
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("Settings")
                Toggle("First", isOn: Binding(get: { firstValue }, set: { firstValue = $0 }))
                Toggle(isOn: Binding(get: { secondValue }, set: { secondValue = $0 })) {
                    HStack(spacing: 1) {
                        Text("Second")
                        Text("option")
                    }
                }
            })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        let moved = renderer.handle(.arrowDown)
        let unfocused = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.space)

        // -- Assert --
        #expect(initial.snapshotText == "Settings         \n[x] First        \n[ ] Second option")
        #expect(!initial.isFocused(column: 0, row: 0))
        #expect(initial.isFocused(column: 0, row: 1))
        #expect(!initial.isFocused(column: 0, row: 2))
        #expect(moved)
        #expect(unfocused.snapshotText == initial.snapshotText)
        #expect(!unfocused.isFocused(column: 0, row: 1))
        #expect(unfocused.isFocused(column: 0, row: 2))
        #expect(unfocused.isFocused(column: 15, row: 2))
        #expect(firstValue)
        #expect(secondValue)
    }

    private struct Settings: View {
        @State private var enabled = false

        var body: some View {
            VStack(alignment: .leading) {
                Toggle("Enabled", isOn: $enabled)
                Text(enabled ? "On" : "Off")
                Button("Enable externally") { enabled = true }
            }
        }
    }

    @Test("Mounted state updates both the toggle and dependent content without scheduling timers")
    func mountedState() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Settings())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.space)
        let update = renderer.render(.now)

        // -- Assert --
        #expect(update.grid?.snapshotText == "[x] Enabled      \nOn               \nEnable externally")
        #expect(update.nextUpdate == nil)
        #expect(try #require(update.grid).isFocused(column: 0, row: 0))
    }

    @Test("An external state write updates an unfocused toggle")
    func externalStateWrite() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Settings())
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let updated = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(updated.snapshotText == "[x] Enabled      \nOn               \nEnable externally")
        #expect(!updated.isFocused(column: 0, row: 0))
        #expect(updated.isFocused(column: 0, row: 2))
    }
}
