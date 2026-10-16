import Foundation
import Testing

@testable import Twill

@Suite("Outline group state and panes")
@MainActor
struct OutlineGroupStateTests {
    private struct Node: Identifiable {
        let id: Int
        var children: [Node]?
    }

    private final class Model {
        var nodes: [Node]

        init(_ nodes: [Node]) { self.nodes = nodes }
    }

    private struct RetainedLabel: View {
        @State private var text: String

        init(_ text: String) { _text = State(wrappedValue: text) }

        var body: some View { Text(text) }
    }

    @Test("Reordering and reparenting visible rows retain keyed state and selected identity")
    func stableIdentity() throws {
        // -- Arrange --
        let model = Model([Node(id: 1, children: [Node(id: 2)]), Node(id: 5)])
        var prefix = "First"
        var selection: Int? = 2
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    model.nodes, children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { [1] }, set: { _ in })
                ) { RetainedLabel("\(prefix) \($0.id)") }
            })
        _ = renderer.render(start)

        // -- Act --
        prefix = "Updated"
        model.nodes.reverse()
        let reordered = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        model.nodes = [Node(id: 2), Node(id: 1, children: []), Node(id: 5)]
        let reparented = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(selection == 2)
        #expect(reordered.isFocused(column: 4, row: 2))
        #expect(reparented.isFocused(column: 2, row: 0))
        #expect(reparented.snapshotText.contains("First 2"))
        #expect(!reparented.snapshotText.contains("Updated"))
    }

    @Test("Hiding and removing rows preserve stored selection and expansion without submitting stale IDs")
    func selectionLifetime() throws {
        // -- Arrange --
        let original = [Node(id: 1, children: [Node(id: 2)]), Node(id: 5)]
        let model = Model(original)
        var selection: Int? = 2
        var expanded: Set<Int> = [1]
        var submitted = false
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    model.nodes, children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
                ) { Text("Node \($0.id)") }.onSubmit { submitted = true }
            })
        _ = renderer.render(start)

        // -- Act --
        expanded = []
        let hidden = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        let retained = selection
        expanded = [1]
        model.nodes = []
        _ = renderer.render(start.addingTimeInterval(2))
        _ = renderer.handle(.enter)
        model.nodes = original
        let restored = try #require(renderer.render(start.addingTimeInterval(3)).grid)

        // -- Assert --
        #expect(retained == 2)
        #expect(selection == 2)
        #expect(expanded == [1])
        #expect(hidden.isFocused(column: 0, row: 0))
        #expect(restored.isFocused(column: 4, row: 1))
        #expect(!submitted)
    }

    @Test("Selection stays visible in an inactive pane and navigation does not move keyboard focus")
    func paneIsolation() throws {
        // -- Arrange --
        var selection: Int? = 1
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                HStack {
                    OutlineGroup(
                        [Node(id: 1, children: [Node(id: 2)])], children: \.children,
                        selection: Binding(get: { selection }, set: { selection = $0 }),
                        expandedIDs: Binding(get: { [1] }, set: { _ in })
                    ) { Text("Node \($0.id)") }
                    ScrollView { Text("Other") }
                }
            })
        _ = renderer.render(start)
        let focusedOutline = renderer.focusTarget()

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(start.addingTimeInterval(1))
        let afterSelection = renderer.focusTarget()
        _ = renderer.handle(.tab)
        let inactive = try #require(renderer.render(start.addingTimeInterval(2)).grid)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.shiftTab)

        // -- Assert --
        #expect(selection == 2)
        #expect(afterSelection === focusedOutline)
        #expect(renderer.focusTarget() === focusedOutline)
        #expect(inactive.isFocused(column: 4, row: 1))
    }

    @Test("Hierarchical navigation reveals a selected child beyond the viewport")
    func automaticReveal() throws {
        // -- Arrange --
        var selection: Int? = 1
        var expanded: Set<Int> = []
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    [Node(id: 1, children: [Node(id: 2)])], children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
                ) { Text("Node \($0.id)") }.frame(height: 1)
            })
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        _ = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.arrowRight)
        let child = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(selection == 2)
        #expect(child.snapshotText == "    Node 2")
        #expect(child.isFocused(column: 4, row: 0))
    }
}
