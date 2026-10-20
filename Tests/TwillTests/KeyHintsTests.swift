import Foundation
import Testing

@testable import Twill

@Suite("Command key hints")
@MainActor
struct KeyHintsTests {
    @Test("Hints display available commands and all alternatives, including display overrides")
    func presentation() {
        // -- Arrange --
        let commands = [
            Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)]) {},
            Command("cancel", title: "Cancel", shortcuts: [KeyboardShortcut(.escape, hint: "Escape")]) {},
            Command("hidden", title: "Unavailable", isEnabled: false, shortcuts: [KeyboardShortcut(.x)]) {},
            Command("plain", title: "No shortcut") {},
        ]
        let renderer = ViewRenderer.make(KeyHints(commands))

        // -- Act --
        let frame = renderer.render(.now)
        let key = renderer.handle(.controlS)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Ctrl-S/Super-s: Save  •  Escape: Cancel")
        #expect(frame.nextUpdate == nil)
        #expect(!key)
    }

    @Test("Inherited disabled state hides command hints without unmounting content")
    func inheritedAvailability() {
        // -- Arrange --
        let commands = [Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)]) {}]
        func content(disabled: Bool) -> some View { KeyHints(commands).disabled(disabled) }
        let renderer = ViewRenderer.make(content(disabled: false))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(disabled: true), at: .now)
        let disabled = renderer.render(.now)
        renderer.update(content(disabled: false), at: .now)
        let enabled = renderer.render(.now)

        // -- Assert --
        #expect(disabled.grid == nil)
        #expect(enabled.grid?.snapshotText == "Ctrl-S: Save")
    }

    @Test("Command updates keep button availability, hint text and shortcuts in sync")
    func changingAvailability() throws {
        // -- Arrange --
        var actions: [String] = []
        func content(available: Bool, title: String, shortcut: KeyEvent) -> some View {
            let command = Command(
                "save", title: title, isEnabled: available,
                shortcuts: [KeyboardShortcut(shortcut)]
            ) { actions.append(title) }
            return VStack(alignment: .leading) {
                Button("Other") { actions.append("other") }
                Button(command)
                KeyHints([command])
            }
        }
        let renderer = ViewRenderer.make(content(available: true, title: "Save", shortcut: .s))
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)

        // -- Act --
        renderer.update(content(available: false, title: "Save", shortcut: .s), at: .now)
        let disabled = try #require(renderer.render(.now).grid)
        let disabledShortcut = renderer.handle(.s)
        _ = renderer.handle(.enter)
        renderer.update(content(available: true, title: "Save changes", shortcut: .x), at: .now)
        let enabled = try #require(renderer.render(.now).grid)
        let oldShortcut = renderer.handle(.s)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(disabled.snapshotText == "Other\nSave ")
        #expect(!disabledShortcut && !oldShortcut)
        #expect(!disabled.snapshotText.contains("s: Save"))
        #expect(enabled.snapshotText.contains("x: Save changes"))
        #expect(actions == ["other", "Save changes"])
    }

    @Test("Empty and unavailable command sets contribute no layout")
    func emptyHints() {
        // -- Arrange --
        let disabled = Command("save", title: "Save", isEnabled: false, shortcuts: [KeyboardShortcut(.s)]) {}
        let noShortcut = Command("other", title: "Other") {}
        let empty = ViewRenderer.make(KeyHints<String>([]))
        let unavailable = ViewRenderer.make(KeyHints([disabled, noShortcut]))

        // -- Act --
        let emptyFrame = empty.render(.now)
        let unavailableFrame = unavailable.render(.now)

        // -- Assert --
        #expect(emptyFrame.grid == nil)
        #expect(unavailableFrame.grid == nil)
        #expect(emptyFrame.nextUpdate == nil && unavailableFrame.nextUpdate == nil)
    }
}
