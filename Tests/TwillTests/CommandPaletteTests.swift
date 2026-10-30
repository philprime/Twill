import Testing

@testable import Twill

@Suite("Command palette interaction")
@MainActor
struct CommandPaletteTests {
    @Test("Advertised shortcut hints keep the surrounding foreground hue with secondary prominence")
    func contextualHints() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            CommandPalette(
                commands: [Command("save", title: "Save", shortcuts: [KeyboardShortcut(.z)]) {}],
                dismiss: {}
            ).foregroundStyle(Color.blue))

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 40)).grid)
        let hints = (0..<grid.size.height).flatMap { row in
            (0..<grid.size.width).compactMap { column in
                grid[column, row] == .glyph("z", width: 1) ? CellPosition(column: column, row: row) : nil
            }
        }
        let hint = try #require(hints.first)

        // -- Assert --
        #expect(hints.count == 1)
        #expect(grid.foreground(column: hint.column, row: hint.row) == .blue)
        #expect(grid.attributes(column: hint.column, row: hint.row) == [.dim])
    }

    @Test("Arrow selection keeps search focused and Enter performs the effective command once")
    func searchSelection() {
        // -- Arrange --
        var actions: [String] = []
        var dismissals = 0
        let renderer = ViewRenderer.make(
            CommandPalette(
                commands: [
                    Command("save", title: "Save") { actions.append("save") },
                    Command("close", title: "Close") { actions.append("close") },
                ], dismiss: { dismissals += 1 }))
        _ = renderer.render(.now)
        let original = renderer.focusTarget()

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let retained = original === renderer.focusTarget()
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(retained && actions == ["close"] && dismissals == 1)
    }

    @Test("Filtering hidden selected IDs falls back without triggering advertised shortcuts")
    func filteringAndShortcuts() throws {
        // -- Arrange --
        var actions: [String] = []
        var dismissals = 0
        let renderer = ViewRenderer.make(
            CommandPalette(
                commands: [
                    Command("save", title: "SAVE", shortcuts: [KeyboardShortcut(.s)]) { actions.append("save") },
                    Command("close", title: "Close") { actions.append("close") },
                ], dismiss: { dismissals += 1 }))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)
        _ = renderer.handle(.a)
        let filtered = try #require(renderer.render(.now).grid)
        let untouched = actions.isEmpty && dismissals == 0
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(filtered.snapshotText.contains("SAVE") && !filtered.snapshotText.contains("Close"))
        #expect(untouched && actions == ["save"] && dismissals == 1)
    }

    @Test("Unavailable commands are omitted and no results do not activate or dismiss")
    func unavailableAndEmpty() throws {
        // -- Arrange --
        var actions = 0
        var dismissals = 0
        let renderer = ViewRenderer.make(
            CommandPalette(
                commands: [
                    Command("hidden", title: "Unavailable action", isEnabled: false) { actions += 1 }
                ], dismiss: { dismissals += 1 }))
        let grid = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let retained = dismissals == 0
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(!grid.snapshotText.contains("Unavailable action"))
        #expect(grid.snapshotText.contains("No matching commands"))
        #expect(retained && dismissals == 1 && actions == 0)
    }

    @Test("Tab enters ordinary list focus and activation uses the same command snapshot")
    func listActivation() {
        // -- Arrange --
        var actions = 0
        var dismissals = 0
        let renderer = ViewRenderer.make(
            CommandPalette(
                commands: [Command(1, title: "Run") { actions += 1 }],
                dismiss: { dismissals += 1 }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == 1 && dismissals == 1)
    }

    @Test("Parent command updates retain the search query and use fresh metadata and actions")
    func updatedCommands() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            CommandPalette(commands: [Command("save", title: "Save") { actions.append("old") }], dismiss: {}))
        _ = renderer.render(.now)
        _ = renderer.handle(.s)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(
            CommandPalette(commands: [Command("save", title: "Save updated") { actions.append("new") }], dismiss: {}),
            at: .now)
        let updated = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(updated.snapshotText.contains("Save updated"))
        #expect(actions == ["new"])
    }

    @Test("Selection reveals commands beyond the bounded visible row count")
    func boundedViewport() throws {
        // -- Arrange --
        let commands = (0..<50).map { Command($0, title: "Task \($0)", action: {}) }
        let renderer = ViewRenderer.make(CommandPalette(commands: commands, maximumVisibleCommands: 4, dismiss: {}))
        _ = renderer.render(.now)

        // -- Act --
        for _ in 0..<20 {
            _ = renderer.handle(.arrowDown)
            _ = renderer.render(.now)
        }
        let moved = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(moved.snapshotText.contains("Task 20"))
        #expect(!moved.snapshotText.contains("Task 0"))
    }
}
