import Foundation
import Testing

@testable import Twill

@Suite("Inherited disabled controls")
@MainActor
struct DisabledViewTests {
    @Test("A sheet without controls remains dismissible beneath a disabled ancestor")
    func disabledAncestorDismissal() {
        // -- Arrange --
        var presented = true
        let renderer = ViewRenderer.make(
            Text("Base")
                .sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                    Text("Help").onKeyPress { key in
                        guard key == .escape else { return .ignored }
                        presented = false
                        return .handled
                    }
                }
                .disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.escape)

        // -- Assert --
        #expect(handled)
        #expect(!presented)
    }

    @Test("Presented controls ignore base availability but preserve disabled state inside the sheet")
    func disabledAncestorControls() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Button("Base") { actions.append("base") }
                .sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                    VStack {
                        Button("Unavailable") { actions.append("unavailable") }
                            .onKeyPress { key in
                                guard key == .x else { return .ignored }
                                actions.append("disabled shortcut")
                                return .handled
                            }
                            .disabled(true)
                        Button("Available") { actions.append("available") }
                    }
                    .onKeyPress { key in
                        guard key == .escape else { return .ignored }
                        presented = false
                        return .handled
                    }
                }
                .disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.x)
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["available"])
        #expect(!presented)
        #expect(renderer.focusTarget() == nil)
    }

    @Test("Disabled controls stay visible but are skipped by Tab and arrow navigation")
    func traversal() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Button("Unavailable") { actions.append("disabled") }.disabled(true)
                Button("First") { actions.append("first") }
                Button("Also unavailable") { actions.append("also disabled") }.disabled(true)
                Button("Last") { actions.append("last") }
            })
        let initial = renderer.render(.now)
        let grid = try #require(initial.grid)

        // -- Act --
        _ = renderer.handle(.enter)
        let forward = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        let backward = renderer.handle(.arrowUp)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.snapshotText.contains("Unavailable"))
        #expect(grid.snapshotText.contains("Also unavailable"))
        #expect(grid.isFocused(column: 0, row: 1))
        #expect(initial.nextUpdate == nil)
        #expect(forward && backward)
        #expect(actions == ["first", "last", "first"])
    }

    @Test("A disabled ancestor cannot be re-enabled by a descendant")
    func inheritedState() {
        // -- Arrange --
        var text = "Original"
        var enabled = false
        var activations = 0
        let renderer = ViewRenderer.make(
            VStack {
                TextField("Name", text: Binding(get: { text }, set: { text = $0 })).disabled(false)
                Toggle("Enabled", isOn: Binding(get: { enabled }, set: { enabled = $0 })).disabled(false)
                Button("Save") { activations += 1 }.disabled(false)
            }.disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        let typed = renderer.handle(.x)
        let toggled = renderer.handle(.space)
        let activated = renderer.handle(.enter)

        // -- Assert --
        #expect(renderer.focusTarget() == nil)
        #expect(!typed && !toggled && !activated)
        #expect(text == "Original")
        #expect(!enabled)
        #expect(activations == 0)
    }

    @Test("Disabled custom controls cannot handle keys when no focus target is available")
    func customHandlers() {
        // -- Arrange --
        var keys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Text("Custom")
                .focusable()
                .onKeyPress {
                    keys.append($0)
                    return .handled
                }
                .disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.x)

        // -- Assert --
        #expect(!handled)
        #expect(keys.isEmpty)
    }

    @Test("Enabled enclosing shortcuts remain available around disabled content")
    func enclosingShortcuts() {
        // -- Arrange --
        var actions = 0
        var shortcuts = 0
        let renderer = ViewRenderer.make(
            Button("Unavailable") { actions += 1 }
                .disabled(true)
                .onKeyPress { key in
                    guard key == .r else { return .ignored }
                    shortcuts += 1
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let shortcut = renderer.handle(.r)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(shortcut)
        #expect(shortcuts == 1)
        #expect(actions == 0)
    }

    @Test("A disabled field cannot show an editing caret through an outer focusable container")
    func disabledCaret() throws {
        // -- Arrange --
        var text = "Name"
        let renderer = ViewRenderer.make(
            TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
                .disabled(true)
                .focusable())

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)
        let typed = renderer.handle(.x)

        // -- Assert --
        #expect(!typed)
        #expect(text == "Name")
        #expect(renderer.caretPosition == nil)
        #expect(!frame.isFocused(column: 0, row: 0))
    }

    @Test("Disabling a focused field hides its caret and moves focus to an enabled control")
    func dynamicFocus() throws {
        // -- Arrange --
        var text = "Name"
        var focused = false
        var saves = 0
        func content(disabled: Bool) -> some View {
            VStack {
                TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
                    .focused(FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 }))
                    .disabled(disabled)
                Button("Save") { saves += 1 }
            }
        }
        let renderer = ViewRenderer.make(content(disabled: false))
        _ = renderer.render(.now)
        let initialCaret = renderer.caretPosition

        // -- Act --
        renderer.update(content(disabled: true), at: .now)
        let disabled = try #require(renderer.render(.now).grid)
        let disabledCaret = renderer.caretPosition
        let lostFocus = !focused
        _ = renderer.handle(.x)
        _ = renderer.handle(.enter)
        renderer.update(content(disabled: false), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.shiftTab)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(initialCaret != nil)
        #expect(disabledCaret == nil && lostFocus)
        #expect(disabled.isFocused(column: 0, row: 1))
        #expect(saves == 1)
        #expect(text == "Namex")
    }

    @Test(
        "Programmatic focus cannot activate a disabled field, regardless of modifier order", arguments: [false, true])
    func programmaticFocus(bindingOutside: Bool) {
        // -- Arrange --
        var focused = true
        var text = ""
        var activated = false
        let focus = FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 })
        let value = Binding(get: { text }, set: { text = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                if bindingOutside {
                    TextField("Disabled", text: value).disabled(true).focused(focus)
                } else {
                    TextField("Disabled", text: value).focused(focus).disabled(true)
                }
                Button("Enabled") { activated = true }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.x)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(text.isEmpty)
        #expect(activated)
        #expect(renderer.caretPosition == nil)
    }

    private struct Counter: View {
        @State private var value = 0
        let disabled: Bool

        var body: some View {
            Button("Count \(value)") { value += 1 }.disabled(disabled)
        }
    }

    @Test("Disabling and enabling a control retains its mounted state")
    func retainedState() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(disabled: false))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(disabled: true), at: .now)
        let disabled = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        renderer.update(Counter(disabled: false), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let enabled = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(disabled.snapshotText == "Count 1")
        #expect(enabled.snapshotText == "Count 2")
    }
}
