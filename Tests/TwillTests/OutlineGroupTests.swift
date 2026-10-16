import Foundation
import Testing

@testable import Twill

@Suite("Outline groups")
@MainActor
struct OutlineGroupTests {
    private struct Node: Identifiable {
        let id: Int
        var children: [Node]?
    }

    private struct Step {
        let key: KeyEvent
        let selection: Int
        let expandedIDs: Set<Int>
    }

    private let nodes = [
        Node(id: 1, children: [Node(id: 2, children: [Node(id: 3)]), Node(id: 4)]),
        Node(id: 5),
    ]

    @Test("Expanded branches render indented keyed rows without evaluating collapsed labels or scheduling work")
    func presentation() throws {
        // -- Arrange --
        var labels: [Int] = []
        let renderer = ViewRenderer.make(
            OutlineGroup(
                nodes, id: \.id, children: \.children,
                selection: Binding(get: { nil }, set: { _ in }),
                expandedIDs: Binding(get: { [1] }, set: { _ in })
            ) { node in
                labels.append(node.id)
                return Text("Node \(node.id)")
            })

        // -- Act --
        let frame = renderer.render(.now)
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.snapshotText == "▾ Node 1  \n  ▸ Node 2\n    Node 4\n  Node 5  ")
        #expect(labels == [1, 2, 4, 5])
        #expect(grid.isFocused(column: 0, row: 0))
        #expect(frame.nextUpdate == nil)
    }

    @Test("Right expands then enters children and Left collapses then selects parents")
    func hierarchicalNavigation() {
        // -- Arrange --
        var selection: Int?
        var expanded: Set<Int> = []
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    nodes, children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
                ) { Text("Node \($0.id)") }
            })
        let steps: [Step] = [
            .init(key: .arrowRight, selection: 1, expandedIDs: [1]),
            .init(key: .arrowRight, selection: 2, expandedIDs: [1]),
            .init(key: .arrowRight, selection: 2, expandedIDs: [1, 2]),
            .init(key: .arrowRight, selection: 3, expandedIDs: [1, 2]),
            .init(key: .arrowLeft, selection: 2, expandedIDs: [1, 2]),
            .init(key: .arrowLeft, selection: 2, expandedIDs: [1]),
            .init(key: .arrowLeft, selection: 1, expandedIDs: [1]),
            .init(key: .arrowLeft, selection: 1, expandedIDs: []),
            .init(key: .arrowLeft, selection: 1, expandedIDs: []),
        ]

        for (offset, step) in steps.enumerated() {
            // -- Act --
            _ = renderer.render(start.addingTimeInterval(Double(offset)))
            let handled = renderer.handle(step.key)

            // -- Assert --
            #expect(handled)
            #expect(selection == step.selection)
            #expect(expanded == step.expandedIDs)
        }
    }

    @Test("Up and Down traverse only visible rows, clamp and submit the effective selection")
    func verticalNavigation() {
        // -- Arrange --
        var selection: Int? = 1
        var submissions: [Int?] = []
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    nodes, children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { [1] }, set: { _ in })
                ) { Text("Node \($0.id)") }
                .onSubmit { submissions.append(selection) }
            })
        let steps: [(KeyEvent, Int)] = [
            (.arrowUp, 1), (.arrowDown, 2), (.arrowDown, 4), (.arrowDown, 5),
            (.arrowDown, 5), (.arrowUp, 4), (.end, 5), (.home, 1), (.enter, 1),
        ]

        for (offset, step) in steps.enumerated() {
            let (key, expectedSelection) = step
            // -- Act --
            _ = renderer.render(start.addingTimeInterval(Double(offset)))
            let handled = renderer.handle(key)

            // -- Assert --
            #expect(handled)
            #expect(selection == expectedSelection)
        }
        #expect(submissions == [1])
    }

    @Test("Leaf navigation does not change expansion and an empty branch can expand and collapse")
    func leavesAndEmptyBranches() {
        // -- Arrange --
        var selection: Int? = 1
        var expanded: Set<Int> = []
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                OutlineGroup(
                    [Node(id: 1), Node(id: 2, children: [])], children: \.children,
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
                ) { Text("Node \($0.id)") }
            })
        let steps: [Step] = [
            .init(key: .arrowRight, selection: 1, expandedIDs: []),
            .init(key: .arrowLeft, selection: 1, expandedIDs: []),
            .init(key: .arrowDown, selection: 2, expandedIDs: []),
            .init(key: .arrowRight, selection: 2, expandedIDs: [2]),
            .init(key: .arrowRight, selection: 2, expandedIDs: [2]),
            .init(key: .arrowLeft, selection: 2, expandedIDs: []),
        ]

        for (offset, step) in steps.enumerated() {
            // -- Act --
            _ = renderer.render(start.addingTimeInterval(Double(offset)))
            let handled = renderer.handle(step.key)

            // -- Assert --
            #expect(handled)
            #expect(selection == step.selection)
            #expect(expanded == step.expandedIDs)
        }
    }

    @Test("Empty outlines consume navigation without submitting stale selections")
    func emptyOutline() {
        // -- Arrange --
        var selection: Int? = 99
        var expanded: Set<Int> = [99]
        var submissions = 0
        let renderer = ViewRenderer.make(
            OutlineGroup(
                [Node](), children: \.children,
                selection: Binding(get: { selection }, set: { selection = $0 }),
                expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
            ) { Text("Node \($0.id)") }.onSubmit { submissions += 1 })
        _ = renderer.render(.now)

        // -- Act --
        let handled = [KeyEvent.arrowDown, .arrowUp, .arrowLeft, .arrowRight, .home, .end, .enter]
            .map { renderer.handle($0) }

        // -- Assert --
        #expect(handled.allSatisfy { $0 })
        #expect(selection == 99)
        #expect(expanded == [99])
        #expect(submissions == 0)
    }
}
