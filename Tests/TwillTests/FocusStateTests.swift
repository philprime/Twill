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
