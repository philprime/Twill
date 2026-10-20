import Testing

@testable import Twill

@Suite("Shortcut scope isolation")
@MainActor
struct KeyboardShortcutIsolationTests {
    @Test("A modal cannot activate shortcuts in its retained underlying screen")
    func modalScope() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        func content() -> some View {
            HStack {
                Button("Base save") { actions.append("base") }.keyboardShortcut(.s)
                Button("Base other") { actions.append("leaked") }.keyboardShortcut(.x)
            }.sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                HStack {
                    Button("Other") {}
                    Button("Sheet save") { actions.append("sheet") }.keyboardShortcut(.s)
                }
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)
        let trapped = renderer.handle(.x)
        let remainedPresented = presented
        presented = false
        renderer.update(content(), at: .now)
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(trapped && remainedPresented)
        #expect(actions == ["sheet", "base"])
    }

    @Test("Only the active tab destination can supply a shortcut")
    func inactiveTabs() {
        // -- Arrange --
        var selection = 0
        var actions: [Int] = []
        func content() -> some View {
            TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
                Tab("First", value: 0) { Button("Save") { actions.append(0) }.keyboardShortcut(.s) }
                Tab("Second", value: 1) { Button("Save") { actions.append(1) }.keyboardShortcut(.s) }
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)
        selection = 1
        renderer.update(content(), at: .now)
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == [0, 1])
    }

    @Test("A dialog shortcut invokes its existing action before dismissing")
    func dialogActivation() {
        // -- Arrange --
        var presented = true
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Text("Base").alert("Retry?", isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button("Retry") { actions.append(presented ? "retry" : "already closed") }.keyboardShortcut(.r)
                Button("Cancel", role: .cancel) { actions.append("cancel") }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.r)

        // -- Assert --
        #expect(actions == ["retry"])
        #expect(!presented)
    }

    @Test("An inner sheet's shortcut does not dismiss an enclosing dialog")
    func nestedSheet() {
        // -- Arrange --
        var outer = true
        var inner = true
        var actions = 0
        let renderer = ViewRenderer.make(
            Text("Base").alert("Outer", isPresented: Binding(get: { outer }, set: { outer = $0 })) {
                Button("Open") {}
                    .sheet(isPresented: Binding(get: { inner }, set: { inner = $0 })) {
                        Button("Inner action") { actions += 1 }.keyboardShortcut(.s)
                    }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.s)

        // -- Assert --
        #expect(actions == 1)
        #expect(outer && inner)
    }

    @Test("Removing a shortcut branch removes its action immediately")
    func removedBranch() {
        // -- Arrange --
        var actions = 0
        func content(visible: Bool) -> some View {
            HStack {
                Button("Other") {}
                if visible { Button("Save") { actions += 1 }.keyboardShortcut(.s) }
            }
        }
        let renderer = ViewRenderer.make(content(visible: true))
        _ = renderer.render(.now)
        _ = renderer.handle(.s)

        // -- Act --
        renderer.update(content(visible: false), at: .now)
        let handled = renderer.handle(.s)

        // -- Assert --
        #expect(!handled)
        #expect(actions == 1)
    }

    @Test("Shortcuts remain available after focus is explicitly cleared")
    func clearedFocus() {
        // -- Arrange --
        var focused = true
        var text = ""
        var saves = 0
        let renderer = ViewRenderer.make(
            VStack {
                TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
                    .focused(FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 }))
                Button("Save") { saves += 1 }.keyboardShortcut(KeyboardShortcut(.s))
            })
        _ = renderer.render(.now)
        focused = false
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.s)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(handled)
        #expect(saves == 1)
        #expect(text.isEmpty)
        #expect(!focused && renderer.caretPosition == nil)
    }
}
