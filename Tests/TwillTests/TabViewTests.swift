import Testing

@testable import Twill

@Suite("Tab view interaction")
@MainActor
struct TabViewTests {
    private enum Page: Hashable { case first, second }

    private struct Fixture: View {
        @State var selection = Page.first
        let capture: (Binding<Page>) -> Void

        var body: some View {
            capture($selection)
            return TabView(selection: $selection) {
                Tab("First", value: Page.first) { Text("First content") }
                Tab("Second", value: Page.second) { Text("Second content") }
            }
        }
    }

    private struct CounterPage: View {
        @State private var count = 0
        let name: String
        let key: () -> Void

        var body: some View {
            VStack(alignment: .leading) {
                Button("\(name): \(count)") { count += 1 }
                Button("\(name) last") { count += 1 }
            }
            .onKeyPress { event in
                guard event == .z else { return .ignored }
                key()
                return .handled
            }
        }
    }

    private struct StatefulTabs: View {
        @State private var selection = Page.first
        let firstKey: () -> Void
        let secondKey: () -> Void

        var body: some View {
            TabView(selection: $selection) {
                Tab("First", value: Page.first) { CounterPage(name: "One", key: firstKey) }
                Tab("Second", value: Page.second) { CounterPage(name: "Two", key: secondKey) }
            }
        }
    }

    @Test("Switching back retains local state and restores each destination's focused control")
    func stateAndFocusRestoration() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(StatefulTabs(firstKey: {}, secondKey: {}))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        let second = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(KeyEvent(.pageUp, modifiers: .control))
        let first = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let incremented = try #require(renderer.render(.now).grid)
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        let restoredSecond = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(second.isFocused(column: 0, row: 1))
        #expect(first.isFocused(column: 0, row: 2))
        #expect(first.snapshotText.contains("One: 1"))
        #expect(incremented.snapshotText.contains("One: 2"))
        #expect(restoredSecond.snapshotText.contains("Two: 1"))
        #expect(restoredSecond.isFocused(column: 0, row: 1))
    }

    @Test("Inactive destinations never receive keys")
    func activeInputOnly() {
        // -- Arrange --
        var first = 0
        var second = 0
        let renderer = ViewRenderer.make(StatefulTabs(firstKey: { first += 1 }, secondKey: { second += 1 }))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        let firstHandled = renderer.handle(.z)
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)
        let secondHandled = renderer.handle(.z)

        // -- Assert --
        #expect(firstHandled && secondHandled)
        #expect(first == 1)
        #expect(second == 1)
    }

    @Test("Returning from the bar restores the active tab's remembered descendant")
    func returningFromBar() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(StatefulTabs(firstKey: {}, secondKey: {}))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.isFocused(column: 0, row: 2))
    }

    @Test("An empty tab view has no frame or focus target and lets keys bubble")
    func emptyTabs() {
        // -- Arrange --
        var selection = Page.first
        let renderer = ViewRenderer.make(
            TabView(selection: Binding(get: { selection }, set: { selection = $0 })) { EmptyView() })

        // -- Act --
        let frame = renderer.render(.now)
        let handled = renderer.handle(.arrowRight)

        // -- Assert --
        #expect(frame.grid == nil)
        #expect(renderer.focusTarget() == nil)
        #expect(!handled)
        #expect(selection == .first)
    }

    private struct DynamicTabs: View {
        @State private var selection = 2
        @State private var values = [1, 2]
        let capture: (Binding<Int>, Binding<[Int]>) -> Void

        var body: some View {
            capture($selection, $values)
            return TabView(selection: $selection) {
                ForEach(values, id: \.self) { value in
                    Tab("Tab \(value)", value: value) { CounterPage(name: "Page \(value)", key: {}) }
                }
            }
        }
    }

    @Test("Inserting and reordering tabs retains keyed state and restores destination focus")
    func dynamicTabs() throws {
        // -- Arrange --
        var selection: Binding<Int>?
        var values: Binding<[Int]>?
        let renderer = ViewRenderer.make(
            DynamicTabs {
                selection = $0
                values = $1
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        values?.wrappedValue = [0, 1, 2]
        selection?.wrappedValue = 1
        let inserted = try #require(renderer.render(.now).grid)
        values?.wrappedValue = [2, 1]
        selection?.wrappedValue = 2
        let reordered = try #require(renderer.render(.now).grid)
        values?.wrappedValue = [1]
        let removed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(inserted.isFocused(column: 0, row: 1))
        #expect(reordered.isFocused(column: 0, row: 1))
        #expect(reordered.snapshotText.contains("Page 2: 1"))
        #expect(removed.snapshotText.hasPrefix("[Tab 1]"))
        #expect(!removed.snapshotText.contains("Page 2"))
        #expect(selection?.wrappedValue == 2)
    }

    @Test("The tab bar marks the bound selection and renders only that tab")
    func visibleSelection() throws {
        // -- Arrange --
        var selection: Binding<Page>?
        let renderer = ViewRenderer.make(Fixture { selection = $0 })

        // -- Act --
        let initial = try #require(renderer.render(.now).grid)
        selection?.wrappedValue = .second
        let updated = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.snapshotText.hasPrefix("[First] Second"))
        #expect(initial.snapshotText.contains("First content"))
        #expect(!initial.snapshotText.contains("Second content"))
        #expect(updated.snapshotText.hasPrefix("First [Second]"))
        #expect(updated.snapshotText.contains("Second content"))
        #expect(!updated.snapshotText.contains("First content"))
    }

    @Test("Left and Right select tabs at the focused bar without wrapping")
    func keyboardSelection() throws {
        // -- Arrange --
        var selection: Binding<Page>?
        let renderer = ViewRenderer.make(Fixture { selection = $0 })
        _ = renderer.render(.now)

        // -- Act --
        let right = renderer.handle(.arrowRight)
        let second = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowRight)
        let lastValue = selection?.wrappedValue
        let left = renderer.handle(.arrowLeft)
        let first = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(right && left)
        #expect(lastValue == .second)
        #expect(second.snapshotText.contains("Second content"))
        #expect(first.snapshotText.contains("First content"))
        #expect(selection?.wrappedValue == .first)
        #expect(first.isFocused(column: 0, row: 0))
    }
}
