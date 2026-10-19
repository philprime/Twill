import Testing

@testable import Twill

@Suite("Keyboard shortcut values")
struct KeyboardShortcutTests {
    @Test("Hints reflect terminal key identities without inferring modifier flags")
    func generatedHints() {
        // -- Arrange --
        let cases: [(KeyEvent, String)] = [
            (.s, "s"), (.S, "S"), (.space, "Space"), (.enter, "Enter"), (.escape, "Esc"),
            (.tab, "Tab"), (.shiftTab, "Shift-Tab"), (.backspace, "Backspace"),
            (.arrowUp, "Up"), (.arrowDown, "Down"), (.arrowLeft, "Left"), (.arrowRight, "Right"),
            (.home, "Home"), (.end, "End"), (.insert, "Insert"), (.delete, "Delete"),
            (.pageUp, "Page Up"), (.pageDown, "Page Down"), (.function(2), "F2"),
            (.controlC, "Ctrl-C"), (.controlS, "Ctrl-S"), (.control(0), "Ctrl-@"), (.control(0x1F), "Ctrl-_"),
            (.control(0x7F), "Ctrl-?"), (.control(0xA0), "Control-0xA0"),
            (.character("s", modifiers: .control), "Ctrl-s"),
            (.character("界"), "界"), (.init(.unknown([0x1B, 0x5B, 0x7A])), "Unknown(1B 5B 7A)"),
        ]

        // -- Act --
        let hints = cases.map { KeyboardShortcut($0.0).hint }

        // -- Assert --
        #expect(hints == cases.map(\.1))
    }

    @Test("All reported modifiers have a stable display order")
    func modifierHints() {
        // -- Arrange --
        let key = KeyEvent.character("x", modifiers: [.shift, .alt, .control, .superKey, .hyper, .meta])

        // -- Act --
        let shortcut = KeyboardShortcut(key)

        // -- Assert --
        #expect(shortcut.key == key)
        #expect(shortcut.hint == "Ctrl-Alt-Shift-Super-Hyper-Meta-x")
    }

    @Test("An explicit hint changes display text without changing the matching key")
    func customHint() {
        // -- Arrange --
        let key = KeyEvent.function(2)

        // -- Act --
        let shortcut = KeyboardShortcut(key, hint: "Save key")

        // -- Assert --
        #expect(shortcut.key == key)
        #expect(shortcut.hint == "Save key")
    }
}
