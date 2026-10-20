import Foundation
import Testing

@testable import Twill

@Suite("Disclosure group focus")
@MainActor
struct DisclosureGroupFocusTests {
    @MainActor private final class Model {
        var expanded = true
        var events: [String] = []
        var text = ""
        var textBinding: Binding<String> { Binding(get: { self.text }, set: { self.text = $0 }) }
        var binding: Binding<Bool> { Binding(get: { self.expanded }, set: { self.expanded = $0 }) }
    }

    @Test("Collapsing focused content returns focus to its header", arguments: [false, true])
    func collapseFocus(scrolling: Bool) throws {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                page(model, scrolling: scrolling)
            })
        _ = renderer.render(start)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Act --
        model.expanded = false
        let grid = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.isFocused(column: 0, row: 1))
        #expect(!grid.isFocused(column: 0, row: 0))
        #expect(model.expanded)
        #expect(model.events == ["child"])
    }

    @Test("Collapsing while focus is outside the group does not steal focus", arguments: [false, true])
    func retainsOutsideFocus(scrolling: Bool) throws {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                page(model, scrolling: scrolling)
            })
        _ = renderer.render(start)

        // -- Act --
        model.expanded = false
        let grid = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.isFocused(column: 0, row: 0))
        #expect(!grid.isFocused(column: 0, row: 1))
        #expect(!model.expanded)
        #expect(model.events == ["before"])
    }

    @Test("Collapsing a programmatically focused editor clears its caret and focuses the header")
    func editorFocus() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(EditorFixture(model: model))
        _ = renderer.render(.now)
        let initialCaret = renderer.caretPosition

        // -- Act --
        _ = renderer.handle(.escape)
        let collapsed = try #require(renderer.render(.now).grid)
        let collapsedCaret = renderer.caretPosition
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(initialCaret != nil)
        #expect(collapsedCaret == nil)
        #expect(collapsed.isFocused(column: 0, row: 1))
        #expect(model.text == "x")
        #expect(model.events.isEmpty)
    }

    @Test("Collapsing an active child pane returns focus to the header instead of another pane")
    func childPane() throws {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                VStack {
                    DisclosureGroup("Details", isExpanded: model.binding) {
                        ScrollView { Button("Child") { model.events.append("child") } }
                    }
                    ScrollView { Button("Other pane") { model.events.append("other") } }
                }
            })
        _ = renderer.render(start)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Act --
        model.expanded = false
        let collapsed = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(collapsed.isFocused(column: 0, row: 0))
        #expect(model.expanded)
        #expect(model.events == ["child"])
    }

    private struct EditorFixture: View {
        @State private var expanded = true
        @FocusState private var editing = true
        let model: Model

        var body: some View {
            VStack(alignment: .leading) {
                Button("Before") { model.events.append("before") }
                DisclosureGroup("Details", isExpanded: $expanded) {
                    TextField("Edit", text: model.textBinding).focused($editing)
                }
            }
            .onKeyPress { key in
                guard key == .escape else { return .ignored }
                expanded = false
                return .handled
            }
        }
    }

    @ViewBuilder private func page(_ model: Model, scrolling: Bool) -> some View {
        if scrolling {
            ScrollView { controls(model) }
        } else {
            controls(model)
        }
    }

    private func controls(_ model: Model) -> some View {
        VStack(alignment: .leading) {
            Button("Before") { model.events.append("before") }
            DisclosureGroup("Details", isExpanded: model.binding) {
                Button("Child") { model.events.append("child") }
            }
            Button("After") { model.events.append("after") }
        }
    }
}
