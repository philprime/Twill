import Testing

@testable import Twill

@Suite("Nested menu navigation")
@MainActor
struct NestedMenuTests {
    @Test("Submenus open without dismissing parents and Escape returns one level")
    func returnOneLevel() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Menu("Root") {
                Menu("More") { Button("Leaf") {} }
                Divider()
                Button("Other") {}
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let parent = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        let child = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.escape)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(parent.snapshotText.contains("More  ▸"))
        #expect(child.snapshotText.contains("Leaf"))
        #expect(restored == parent)
    }

    @Test("Right opens a focused submenu and Left returns without invoking an action")
    func directionalNavigation() throws {
        // -- Arrange --
        var actions = 0
        let renderer = ViewRenderer.make(
            Menu("Root") {
                Menu("More") { Button("Leaf") { actions += 1 } }
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        let child = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        let parent = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(child.snapshotText.contains("Leaf"))
        #expect(parent.snapshotText.contains("More  ▸") && actions == 0)
    }

    @Test("Leaf shortcuts close the menu chain and restore the root opener")
    func leafAction() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                Button("Before") { actions.append("before") }
                Menu("Root") {
                    Button("Parent") { actions.append("parent") }.keyboardShortcut(.p)
                    Menu("More") { Button("Leaf") { actions.append("leaf") }.keyboardShortcut(.l) }
                }
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.p)
        _ = renderer.handle(.l)
        let closed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let reopened = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(actions == ["leaf"])
        #expect(closed.snapshotText == "Before Root")
        #expect(reopened.snapshotText.contains("Parent"))
    }

    private struct Dynamic: View {
        @State private var showChild = true
        let capture: (Binding<Bool>) -> Void
        let action: @MainActor () -> Void
        var body: some View {
            capture($showChild)
            return Menu("Root") {
                if showChild { Menu("More") { Button("Leaf") {} } }
                Button("Survivor", action: action)
            }
        }
    }

    @Test("Removing a presented submenu restores valid parent focus")
    func removedSubmenu() throws {
        // -- Arrange --
        var show: Binding<Bool>?
        var actions = 0
        let renderer = ViewRenderer.make(Dynamic(capture: { show = $0 }, action: { actions += 1 }))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        show?.wrappedValue = false
        let parent = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(parent.snapshotText.contains("Survivor") && !parent.snapshotText.contains("Leaf"))
        #expect(actions == 1)
    }

    @Test("Leaf dismissal stops at an unrelated ordinary sheet")
    func sheetBoundary() throws {
        // -- Arrange --
        var presented = true
        var actions = 0
        let renderer = ViewRenderer.make(
            Text("Base").sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Menu("Root") { Menu("More") { Button("Leaf") { actions += 1 } } }
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let sheet = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(presented && actions == 1)
        #expect(sheet.snapshotText == "Root")
    }

    @Test("Dividers and disabled submenus add no focus stop")
    func passiveRows() {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Menu("Root") {
                Button("First") { actions.append("first") }
                Divider()
                Menu("Disabled") { Button("Hidden") {} }.disabled(true)
                Divider()
                Button("Last") { actions.append("last") }
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["last"])
    }
}
