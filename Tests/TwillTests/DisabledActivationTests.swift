import Testing

@testable import Twill

@Suite("Disabled action routing")
@MainActor
struct DisabledActivationTests {
    @Test("Disabled menu content cannot invoke its shortcut or its focused action")
    func menuShortcuts() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let presentation = Binding(get: { presented }, set: { presented = $0 })
        let renderer = ViewRenderer.make(
            Text("Base").sheet(isPresented: presentation) {
                MenuContent(
                    title: "Actions",
                    items: [MenuItem("Save", shortcuts: [KeyboardShortcut(.s, hint: "s")]) { actions.append("save") }],
                    isPresented: presentation
                ).disabled(true)
            })
        _ = renderer.render(.now)

        // -- Act --
        let shortcut = renderer.handle(.s)
        let enter = renderer.handle(.enter)

        // -- Assert --
        #expect(shortcut && enter)
        #expect(actions.isEmpty)
        #expect(presented)
    }

    @Test("A disabled cancel action is not invoked by Escape")
    func disabledCancellation() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Text("Base").alert("Failure", isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button("Retry") { actions.append("retry") }
                Button("Cancel", role: .cancel) { actions.append("cancel") }.disabled(true)
            })
        _ = renderer.render(.now)

        // -- Act --
        let escaped = renderer.handle(.escape)

        // -- Assert --
        #expect(escaped)
        #expect(actions.isEmpty)
        #expect(!presented)
    }

    @Test("A disabled cancel action cannot make destructive confirmation the default")
    func safeDisabledCancellation() throws {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog(
                "Delete?", isPresented: Binding(get: { presented }, set: { presented = $0 })
            ) {
                Button("Delete", role: .destructive) { actions.append("delete") }
                Button("Keep", role: .cancel) { actions.append("keep") }.disabled(true)
            })

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(frame.snapshotText.contains("Cancel"))
        #expect(actions.isEmpty)
        #expect(!presented)
    }

    @Test("An alert with only disabled actions does not activate or invent an enabled fallback")
    func disabledDialogActions() throws {
        // -- Arrange --
        var presented = true
        var activations = 0
        let renderer = ViewRenderer.make(
            Text("Base").alert("Unavailable", isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button("Retry") { activations += 1 }.disabled(true)
            })
        let frame = try #require(renderer.render(.now).grid)

        // -- Act --
        let handled = renderer.handle(.enter)
        let stayedPresented = presented
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(handled)
        #expect(stayedPresented)
        #expect(activations == 0)
        #expect(frame.snapshotText.contains("Retry"))
        #expect(!frame.snapshotText.contains("OK"))
        #expect(!presented)
    }

    @Test("Disabling a focused dialog action falls back before direct Enter routing")
    func changingDialogAction() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        func content(disabled: Bool) -> some View {
            Text("Base").alert("Retry?", isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button("Retry") { actions.append("retry") }.disabled(disabled)
                Button("Later") { actions.append("later") }
            }
        }
        let renderer = ViewRenderer.make(content(disabled: false))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(disabled: true), at: .now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["later"])
        #expect(!presented)
    }

    private struct Tabs: View {
        @State private var selection = 0
        let captureSelection: @MainActor (Binding<Int>) -> Void

        var body: some View {
            captureSelection($selection)
            return TabView(selection: $selection) {
                Tab("First", value: 0) { Button("A") {} }
                Tab("Unavailable", value: 1) { Button("B") {} }.disabled(true)
                Tab("Last", value: 2) { Button("C") {} }
            }
        }
    }

    @Test("Tab selection skips disabled destinations while keeping their titles visible")
    func disabledTabs() throws {
        // -- Arrange --
        var selection: Binding<Int>?
        let renderer = ViewRenderer.make(Tabs { selection = $0 })
        let frame = try #require(renderer.render(.now).grid)
        let binding = try #require(selection)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        let forward = binding.wrappedValue
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(frame.snapshotText.contains("Unavailable"))
        #expect(forward == 2)
        #expect(binding.wrappedValue == 0)
    }
}
