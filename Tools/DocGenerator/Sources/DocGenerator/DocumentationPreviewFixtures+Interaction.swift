@testable import Twill

extension DocumentationPreviewFixture {
    static var keyHintsFixture: Self {
        Self("KeyHints", "Available commands share their current titles and shortcut hints with controls.") {
            KeyHints([
                Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)]) {},
                Command("cancel", title: "Cancel", shortcuts: [KeyboardShortcut(.escape)]) {},
            ])
        }
    }

    static var disabledFixture: Self {
        Self("DisabledView", "Disabled controls stay visible but do not receive focus or activate.") {
            Button("Unavailable") {}.disabled(true)
        }
    }

    static var focusableFixture: Self {
        Self(
            "FocusableView",
            "A focusable text target. Reverse video indicates focus; "
                + "enclosing key handlers define actions."
        ) {
            Text("Keyboard target").focusable()
        }
    }

    static var keyboardShortcutFixture: Self {
        Self("KeyboardShortcutView", "A shortcut reuses the button action without changing its label.") {
            Button("Save") {}.keyboardShortcut(.s)
        }
    }
}
