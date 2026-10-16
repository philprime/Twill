import Foundation
import Testing

@testable import Twill

@Suite("Disclosure groups")
@MainActor
struct DisclosureGroupTests {
    @MainActor private final class Model {
        var expanded = false
        var contentEvaluations = 0
        var events: [String] = []
        var binding: Binding<Bool> { Binding(get: { self.expanded }, set: { self.expanded = $0 }) }
    }

    @Test("Collapsed groups render only their labeled control without evaluating content")
    func collapsedContent() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            DisclosureGroup("Details", isExpanded: model.binding) {
                model.contentEvaluations += 1
                return Text("Hidden")
            })

        // -- Act --
        let frame = renderer.render(.now)
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.snapshotText == "▸ Details")
        #expect(grid.isFocused(column: 0, row: 0))
        #expect(model.contentEvaluations == 0)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Expanded content is vertically grouped and indented beneath a custom label")
    func expandedContent() throws {
        // -- Arrange --
        let model = Model()
        model.expanded = true
        let renderer = ViewRenderer.make(
            DisclosureGroup(isExpanded: model.binding) {
                Text("One")
                Text("Two")
            } label: {
                HStack {
                    Text("Custom")
                    Text("label")
                }
            })

        // -- Act --
        let frame = renderer.render(.now)
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.snapshotText == "▾ Custom label\n  One         \n  Two         ")
        #expect(grid.isFocused(column: 2, row: 0))
        #expect(!grid.isFocused(column: 2, row: 1))
        #expect(frame.nextUpdate == nil)
    }

    @Test("Enter and Space activate the header exactly once", arguments: [KeyEvent.enter, .space])
    func activation(key: KeyEvent) {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            DisclosureGroup("Details", isExpanded: model.binding) { Text("Content") }
                .onKeyPress { _ in
                    model.events.append("parent")
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(key)

        // -- Assert --
        #expect(handled)
        #expect(model.expanded)
        #expect(model.events.isEmpty)
    }

    @Test("Unrelated keys bubble without changing expansion")
    func ignoredKey() {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            DisclosureGroup("Details", isExpanded: model.binding) { Text("Content") }
                .onKeyPress { _ in
                    model.events.append("parent")
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(!model.expanded)
        #expect(model.events == ["parent"])
    }

    @Test("Collapsed children are skipped during focus traversal")
    func hiddenFocus() {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            VStack {
                DisclosureGroup("Details", isExpanded: model.binding) {
                    Button("Hidden") { model.events.append("hidden") }
                }
                Button("After") { model.events.append("after") }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(model.events == ["after"])
        #expect(!model.expanded)
    }
}
