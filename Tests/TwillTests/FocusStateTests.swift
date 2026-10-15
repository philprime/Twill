import Foundation
import Testing

@testable import Twill

@Suite("Programmatic focus")
@MainActor
struct FocusStateTests {
    @Test("A shortcut focuses an editable field outside a pane and submit restores the pane item")
    func searchRoundTrip() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(SearchFocusFixture())
        let initial = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.slash)
        let searching = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.g)
        let typed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let submitted = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.slash)
        _ = renderer.render(.now)
        _ = renderer.handle(.escape)
        let escaped = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.isFocused(column: 0, row: 1))
        #expect(searching.isFocused(column: 0, row: 0))
        #expect(
            typed.snapshotText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } == [
                "g", "One", "Two",
            ])
        #expect(submitted.isFocused(column: 0, row: 2))
        #expect(escaped.isFocused(column: 0, row: 2))
        #expect(escaped.snapshotText == typed.snapshotText)
    }

    @Test("Clearing a Boolean focus binding removes the field caret")
    func clearsFocus() throws {
        // -- Arrange --
        var focused = true
        var text = "Name"
        let binding = FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 })
        let renderer = ViewRenderer.make(
            TextField("Search", text: Binding(get: { text }, set: { text = $0 })).focused(binding))
        _ = renderer.render(.now)

        // -- Act --
        focused = false
        let frame = try #require(renderer.render(.now).grid)
        let handled = renderer.handle(.a)

        // -- Assert --
        #expect(!focused)
        #expect(!frame.isFocused(column: 0, row: 0))
        #expect(renderer.caretPosition == nil)
        #expect(!handled)
        #expect(text == "Name")
    }

    @Test("Traversal outside a pane retains focus on an unbound control")
    func retainsUnboundFocusOutsidePane() throws {
        // -- Arrange --
        var firstFocused = true
        let binding = FocusState<Bool>.Binding(get: { firstFocused }, set: { firstFocused = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                Text("First").focusable().focused(binding)
                Text("Second").focusable()
                ScrollView { Text("Pane").focusable() }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let frame = try #require(renderer.render(.now).grid)
        let unchanged = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(!firstFocused)
        #expect(frame.isFocused(column: 0, row: 1))
        #expect(!frame.isFocused(column: 0, row: 2))
        #expect(unchanged == frame)
    }

    @Test("A newly activated Boolean binding takes focus from the current control", arguments: [false, true])
    func transfersIndependentBooleanFocus(toSecond: Bool) throws {
        // -- Arrange --
        var first = toSecond
        var second = !toSecond
        let firstBinding = FocusState<Bool>.Binding(get: { first }, set: { first = $0 })
        let secondBinding = FocusState<Bool>.Binding(get: { second }, set: { second = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                Text("First").focusable().focused(firstBinding)
                Text("Second").focusable().focused(secondBinding)
            })
        _ = renderer.render(.now)

        // -- Act --
        if toSecond { second = true } else { first = true }
        let frame = try #require(renderer.render(.now).grid)
        let unchanged = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(first == !toSecond)
        #expect(second == toSecond)
        #expect(frame.isFocused(column: 0, row: toSecond ? 1 : 0))
        #expect(unchanged == frame)
    }

    @Test("Nested bindings sharing focus state settle without invalidating unchanged frames")
    func nestedBindingsSettle() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(NestedFocusFixture())
        _ = renderer.render(.now)
        var invalidations = 0
        renderer.onInvalidation = { invalidations += 1 }

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(frame.isFocused(column: 0, row: 0))
        #expect(invalidations == 0)
    }

    @Test("Automatic traversal updates bound focus without pinning it to the requested item")
    func traversalUpdatesBinding() {
        // -- Arrange --
        var selection: Int? = 1
        let binding = FocusState<Int?>.Binding(
            get: { selection }, set: { selection = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                Text("One").focusable().focused(binding, equals: 1)
                Text("Two").focusable().focused(binding, equals: 2)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(selection == 2)
    }
}

@MainActor
private struct NestedFocusFixture: View {
    @FocusState private var focus: Int? = 1

    var body: some View {
        VStack {
            Text("Child").focusable().focused($focus, equals: 2)
        }
        .focused($focus, equals: 1)
    }
}

@MainActor
private struct SearchFocusFixture: View {
    private enum Focus: Hashable {
        case search
        case items
    }

    @State private var query = ""
    @FocusState private var focus: Focus? = .items

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search", text: $query)
                .focused($focus, equals: .search)
                .onSubmit { focus = .items }
            ScrollView {
                VStack {
                    Text("One").focusable()
                    Text("Two").focusable()
                }
            }
            .focused($focus, equals: .items)
        }
        .onKeyPress { key in
            switch key {
            case .slash: focus = .search
            case .escape: focus = .items
            default: return .ignored
            }
            return .handled
        }
    }
}
