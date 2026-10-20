import Testing

@testable import Twill

@Suite("Command palette scope and identity")
@MainActor
struct CommandPaletteScopeTests {
    private struct Fixture: View {
        @State private var presented = false
        let action: @MainActor (String) -> Void
        var body: some View {
            let save = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)]) { action("save") }
            return HStack {
                Button("Before") { action("before") }
                Button("Open") {
                    action("open")
                    presented = true
                }
                Button(save)
            }.commandPalette(isPresented: $presented, commands: [save])
        }
    }

    @Test("Search traps command chords and dismissal restores the opener with a fresh query")
    func modalScope() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(Fixture(action: { actions.append($0) }))
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.s)
        _ = renderer.render(.now)
        let before = actions
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let reopened = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.escape)
        let closed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(before == ["open"])
        #expect(actions == ["open", "save", "open"])
        #expect(reopened.snapshotText.contains("Search commands"))
        #expect(closed.snapshotText == "Before Open Save")
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return CommandPalette(commands: [Command(1, title: "Run", action: {})], dismiss: {})
        }
    }

    @Test("Resize uses cached search/list descriptions without reevaluating bodies")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        let initial = try #require(renderer.render(.now, proposal: .init(width: 40, height: 16)).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 24, height: 12)))
        let restored = try #require(renderer.drawFrame(proposal: .init(width: 40, height: 16)))

        // -- Assert --
        #expect(narrow.size.width == 24)
        #expect(restored == initial && evaluations == 1)
    }

    @Test("A command becoming unavailable cannot activate from retained selection")
    func availabilityUpdate() throws {
        // -- Arrange --
        var actions = 0
        var dismissals = 0
        func content(_ enabled: Bool) -> some View {
            CommandPalette(
                commands: [Command(1, title: "Run", isEnabled: enabled) { actions += 1 }],
                dismiss: { dismissals += 1 })
        }
        let renderer = ViewRenderer.make(content(true))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(false), at: .now)
        let changed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(changed.snapshotText.contains("No matching commands"))
        #expect(actions == 0 && dismissals == 0)
    }
}
