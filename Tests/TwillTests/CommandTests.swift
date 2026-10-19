import Foundation
import Testing

@testable import Twill

@Suite("Reusable command metadata")
@MainActor
struct CommandTests {
    @Test("Commands expose stable identity and metadata and reject unavailable direct actions")
    func metadata() {
        // -- Arrange --
        var actions = 0
        let shortcut = KeyboardShortcut(.controlS, hint: "Save key")
        let command = Command("save", title: "Save", isEnabled: false, role: .destructive, shortcuts: [shortcut]) {
            actions += 1
        }

        // -- Act --
        command.perform()
        let updated = Command("save", title: "Save changes") { actions += 1 }
        updated.perform()

        // -- Assert --
        #expect(command.id == updated.id)
        #expect(command.title == "Save")
        #expect(!command.isEnabled)
        #expect(command.role == .destructive)
        #expect(command.shortcuts.map(\.hint) == ["Save key"])
        #expect(actions == 1)
    }

    @Test("Command buttons reuse all shortcut alternatives without changing focus")
    func buttonActions() {
        // -- Arrange --
        var actions: [String] = []
        let save = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)]) {
            actions.append("save")
        }
        let renderer = ViewRenderer.make(
            HStack {
                Button("Other") { actions.append("other") }
                Button(save)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.superS)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["save", "save", "other"])
    }

    @Test("Disabled command buttons stay visible but cannot receive focus or shortcuts")
    func unavailableButton() throws {
        // -- Arrange --
        var actions: [String] = []
        let save = Command("save", title: "Save", isEnabled: false, shortcuts: [KeyboardShortcut(.s)]) {
            actions.append("save")
        }
        let renderer = ViewRenderer.make(
            HStack {
                Button(save)
                Button("Other") { actions.append("other") }
            })
        let frame = try #require(renderer.render(.now).grid)

        // -- Act --
        let shortcut = renderer.handle(.s)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(frame.snapshotText == "Save Other")
        #expect(!shortcut)
        #expect(actions == ["other"])
    }

    @Test("Inherited disabled state cannot be overridden by an available command")
    func inheritedAvailability() {
        // -- Arrange --
        var actions = 0
        let command = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.s)]) { actions += 1 }
        let renderer = ViewRenderer.make(Button(command).disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        let shortcut = renderer.handle(.s)
        let enter = renderer.handle(.enter)

        // -- Assert --
        #expect(!shortcut && !enter)
        #expect(actions == 0)
    }

    @Test("Command roles participate in safe dialog cancellation")
    func dialogRoles() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let remove = Command("delete", title: "Delete", role: .destructive) { actions.append("delete") }
        let cancel = Command("cancel", title: "Keep", role: .cancel) { actions.append("cancel") }
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog(
                "Delete?", isPresented: Binding(get: { presented }, set: { presented = $0 })
            ) {
                Button(remove)
                Button(cancel)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["cancel"])
        #expect(!presented)
    }

    @Test("An open menu follows updated command availability, title and shortcut metadata")
    func menuMetadataUpdates() throws {
        // -- Arrange --
        var actions: [String] = []
        func content(available: Bool, title: String, key: KeyEvent) -> some View {
            let command = Command(
                "save", title: title, isEnabled: available,
                shortcuts: [KeyboardShortcut(key)]
            ) { actions.append(title) }
            return Menu("Actions", items: [MenuItem(command)])
        }
        let renderer = ViewRenderer.make(content(available: true, title: "Save", key: .s))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(available: false, title: "Save", key: .s), at: .now)
        let disabled = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.s)
        renderer.update(content(available: true, title: "Store", key: .x), at: .now)
        let enabled = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.s)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(disabled.snapshotText.contains("Save  [s] (disabled)"))
        #expect(enabled.snapshotText.contains("Store  [x]"))
        #expect(actions == ["Store"])
    }

    @Test("Command shortcuts stay inside the active modal scope")
    func modalCommands() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let base = Command("base", title: "Base", shortcuts: [KeyboardShortcut(.s)]) { actions.append("base") }
        let modal = Command("modal", title: "Modal", shortcuts: [KeyboardShortcut(.s)]) { actions.append("modal") }
        let renderer = ViewRenderer.make(
            Button(base).sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button(modal)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == ["modal"])
        #expect(presented)
    }

    private struct Counter: View {
        @State private var count = 0
        let commandID: Int

        var body: some View {
            Button(Command(commandID, title: "Count \(count)") { count += 1 })
        }
    }

    @Test("Logical command identity does not replace mounted view identity")
    func commandIdentity() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(commandID: 1))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(commandID: 2), at: .now)
        _ = renderer.handle(.enter)
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Count 2")
    }

    @Test("Menu items reuse command alternatives, role and action")
    func menuActions() throws {
        // -- Arrange --
        var actions = 0
        let command = Command(
            "save", title: "Save", role: .destructive,
            shortcuts: [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)]
        ) { actions += 1 }
        let host = ViewHost(
            rootView: Menu("Actions", items: [MenuItem(command)]),
            runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.enter)
        _ = host.handle(.superS)
        _ = host.handle(.enter)
        _ = host.handle(.controlS)

        // -- Assert --
        #expect(actions == 2)
    }
}
