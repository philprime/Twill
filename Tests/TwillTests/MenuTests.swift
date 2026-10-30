import Testing

@testable import Twill

@Suite("Menus")
@MainActor
struct MenuTests {
    @Test("Opening a menu shows labels, shortcut hints and disabled actions without scheduling work")
    func presentation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Menu("Actions") {
                Button("Save") {}.keyboardShortcut(KeyboardShortcut(.s, hint: "s"))
                Button("Delete") {}.disabled(true)
            })
        let closed = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let open = renderer.render(.now)

        // -- Assert --
        #expect(closed.grid?.snapshotText == "Actions")
        let text = try #require(open.grid?.snapshotText)
        #expect(text.contains("Save  [s]"))
        #expect(text.contains("Delete (disabled)"))
        #expect(open.nextUpdate == nil)
    }

    @Test("Arrow navigation skips disabled items and activation dismisses the menu")
    func navigation() throws {
        // -- Arrange --
        var actions: [String] = []
        let host = ViewHost(
            rootView: Menu("Actions") {
                Button("Disabled first") { actions.append("disabled first") }.disabled(true)
                Button("Save") { actions.append("save") }
                Button("Disabled middle") { actions.append("disabled middle") }.disabled(true)
                Button("Delete") { actions.append("delete") }
            }, runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.enter)
        _ = host.handle(.arrowDown)
        _ = host.handle(.enter)
        _ = host.handle(.enter)
        _ = host.handle(.arrowDown)
        _ = host.handle(.arrowUp)
        _ = host.handle(.enter)

        // -- Assert --
        #expect(actions == ["delete", "save"])
    }

    @Test("Shortcuts match modifiers, ignore disabled actions and dismiss only on activation")
    func shortcuts() throws {
        // -- Arrange --
        var actions: [String] = []
        let shortcut = KeyEvent.character("s", modifiers: .control)
        let host = ViewHost(
            rootView: Menu("Actions") {
                Button("Save") { actions.append("save") }.keyboardShortcut(KeyboardShortcut(shortcut, hint: "Ctrl-S"))
                Button("Delete") { actions.append("delete") }.keyboardShortcut(KeyboardShortcut(.d, hint: "d"))
                    .disabled(true)
            }, runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.enter)
        let disabled = host.handle(.d)
        let unmodified = host.handle(.s)
        _ = host.handle(shortcut)
        _ = host.handle(shortcut)

        // -- Assert --
        #expect(disabled)
        #expect(unmodified)
        #expect(actions == ["save"])
    }

    @Test("Escape traps input and restores the opener rather than the first control")
    func dismissal() throws {
        // -- Arrange --
        var actions: [String] = []
        let host = ViewHost(
            rootView: HStack {
                Button("Other") { actions.append("other") }
                Menu("Actions") { Button("Save") { actions.append("save") } }
            }.onKeyPress { key in
                guard key == .x else { return .ignored }
                actions.append("leaked")
                return .handled
            }, runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.arrowRight)
        _ = host.handle(.enter)
        let trapped = host.handle(.x)
        _ = host.handle(.escape)
        _ = host.handle(.enter)
        _ = host.handle(.enter)

        // -- Assert --
        #expect(trapped)
        #expect(actions == ["save"])
    }

    @Test("An open menu remains dismissible when its ancestor becomes disabled")
    func disabledAncestorDismissal() throws {
        // -- Arrange --
        var activations = 0
        func content(disabled: Bool) -> some View {
            Menu("Actions") {
                Button("Save") { activations += 1 }
                Button("Unavailable") { activations += 1 }
                    .keyboardShortcut(KeyboardShortcut(.u, hint: "u"))
                    .disabled(true)
            }.disabled(disabled)
        }
        let renderer = ViewRenderer.make(content(disabled: false))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(disabled: true), at: .now)
        let open = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.u)
        let handled = renderer.handle(.escape)
        let closed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(open.snapshotText.contains("Save"))
        #expect(handled)
        #expect(closed.snapshotText == "Actions")
        #expect(activations == 0)
        #expect(renderer.focusTarget() == nil)
    }

    @Test("Empty and entirely disabled menus can be dismissed without activating anything", arguments: [false, true])
    func noEnabledItems(empty: Bool) throws {
        // -- Arrange --
        var activations = 0
        let host = ViewHost(
            rootView: Menu("Actions") {
                if !empty {
                    Button("Unavailable") { activations += 1 }.keyboardShortcut(KeyboardShortcut(.u, hint: "u"))
                        .disabled(true)
                }
            }, runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.enter)
        _ = host.handle(.enter)
        let trapped = host.handle(.u)
        _ = host.handle(.escape)
        _ = host.handle(.enter)
        _ = host.handle(.escape)

        // -- Assert --
        #expect(trapped)
        #expect(activations == 0)
        #expect(!host.handle(.u))
    }
}
