import Foundation
import Testing

@testable import Twill

@Suite("Scoped button shortcuts")
@MainActor
struct KeyboardShortcutRoutingTests {
    @Test("A shortcut reuses its button action without moving focus or decorating its label")
    func buttonAction() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") { actions.append("other") }
                Button("Save") { actions.append("save") }.keyboardShortcut(.s)
            })
        let initial = renderer.render(.now)

        // -- Act --
        let shortcut = renderer.handle(.s)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(shortcut)
        #expect(actions == ["save", "other"])
        #expect(try #require(initial.grid).snapshotText == "Other Save")
        #expect(initial.nextUpdate == nil)
    }

    @Test("Alternative shortcuts share one action and leave focus unchanged")
    func alternativeKeys() {
        // -- Arrange --
        var actions: [String] = []
        let shortcuts = [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)]
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") { actions.append("other") }
                Button("Save") { actions.append("save") }.keyboardShortcut(shortcuts)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.superS)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["save", "save", "other"])
    }

    @Test("Empty shortcut arrays register no action and duplicate alternatives activate only once")
    func emptyAndDuplicateKeys() {
        // -- Arrange --
        var emptyActions = 0
        var duplicateActions = 0
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") {}
                Button("Empty") { emptyActions += 1 }.keyboardShortcut([])
                Button("Duplicates") { duplicateActions += 1 }
                    .keyboardShortcut([KeyboardShortcut(.s), KeyboardShortcut(.s)])
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(emptyActions == 0)
        #expect(duplicateActions == 1)
    }

    @Test("Disabled shortcuts are skipped regardless of modifier order", arguments: [false, true])
    func disabledActions(disabledOutside: Bool) {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") {}
                if disabledOutside {
                    Button("Unavailable") { actions.append("disabled") }.keyboardShortcut(.s).disabled(true)
                } else {
                    Button("Unavailable") { actions.append("disabled") }.disabled(true).keyboardShortcut(.s)
                }
                VStack {
                    Button("Inherited") { actions.append("inherited") }.disabled(false).keyboardShortcut(.s)
                }.disabled(true)
                Button("Enabled") { actions.append("enabled") }.keyboardShortcut(.s)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == ["enabled"])
    }

    @Test("Nearest enclosing content wins and duplicate shortcuts follow composition order")
    func nearestScope() {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            VStack {
                HStack {
                    Button("Start") {}
                    Button("Outer save") { actions.append("outer") }.keyboardShortcut(.s)
                }
                HStack {
                    Button("Local") { actions.append("local") }
                    Button("First") { actions.append("first") }.keyboardShortcut(.s)
                    Button("Second") { actions.append("second") }.keyboardShortcut(.s)
                }
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.tab)

        // -- Act --
        _ = renderer.handle(.s)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == ["first", "local", "second"])
    }

    @Test("Editors consume editing keys before shortcuts but leave unhandled control bytes available")
    func editorPrecedence() {
        // -- Arrange --
        var text = ""
        var saved: [String] = []
        var intercepted = 0
        let renderer = ViewRenderer.make(
            VStack {
                TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
                Button("Letter") { intercepted += 1 }.keyboardShortcut(.s)
                Button("Arrow") { intercepted += 1 }.keyboardShortcut(.arrowLeft)
                Button("Save") { saved.append(text) }.keyboardShortcut(.controlS)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.a)

        // -- Assert --
        #expect(text == "as")
        #expect(saved == ["s"])
        #expect(intercepted == 0)
    }

    @Test("Super-S can activate a shortcut while either text editor is focused", arguments: [false, true])
    func superSave(multiline: Bool) {
        // -- Arrange --
        var text = "Draft"
        var saved: [String] = []
        let binding = Binding(get: { text }, set: { text = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                if multiline { TextEditor(text: binding) } else { TextField("Name", text: binding) }
                Button("Save") { saved.append(text) }.keyboardShortcut(.superS)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.superS)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(saved == ["Draft"])
        #expect(text == "Draftx")
    }

    @Test("Existing scoped handlers get first refusal before registered action shortcuts")
    func scopedHandlerPrecedence() {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") {}
                Button("Save") { actions.append("save") }.keyboardShortcut(.s)
            }.onKeyPress { key in
                guard key == .s else { return .ignored }
                actions.append("handler")
                return .handled
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == ["handler"])
    }

    @Test("Matching is exact, including character case and terminal-reported modifiers")
    func exactMatching() {
        // -- Arrange --
        var actions = 0
        let key = KeyEvent.character("s", modifiers: .control)
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") {}
                Button("Save") { actions += 1 }.keyboardShortcut(KeyboardShortcut(key, hint: "Ctrl-S"))
            })
        _ = renderer.render(.now)

        // -- Act --
        let plain = renderer.handle(.s)
        let uppercase = renderer.handle(.character("S", modifiers: .control))
        let controlByte = renderer.handle(.controlS)
        let matching = renderer.handle(key)

        // -- Assert --
        #expect(!plain && !uppercase && !controlByte)
        #expect(matching)
        #expect(actions == 1)
    }

    @Test("A shortcut does not choose an arbitrary button from a multi-control container")
    func unboundContainer() {
        // -- Arrange --
        var actions = 0
        let renderer = ViewRenderer.make(
            HStack {
                Button("First") { actions += 1 }
                Button("Second") { actions += 1 }
            }.keyboardShortcut(.s))
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.s)

        // -- Assert --
        #expect(!handled)
        #expect(actions == 0)
    }

    private struct Counter: View {
        @State private var count = 0
        let key: KeyEvent

        var body: some View {
            Button("Count \(count)") { count += 1 }.keyboardShortcut(key)
        }
    }

    @Test("Updating shortcut metadata removes the old key and preserves mounted state")
    func changedShortcut() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(key: .s))
        _ = renderer.render(.now)
        _ = renderer.handle(.s)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(key: .x), at: .now)
        _ = renderer.render(.now)
        let old = renderer.handle(.s)
        let current = renderer.handle(.x)
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(!old && current)
        #expect(frame.grid?.snapshotText == "Count 2")
    }
}
