import Foundation
import Testing

@testable import Twill

@Suite("Item-aware collection activation")
@MainActor
struct CollectionActivationTests {
    private enum Kind: CaseIterable { case list, table, outline }
    private struct Row: Identifiable {
        let id: Int
        var title = "Original"
        var children: [Row]?
    }
    private let rows = [Row(id: 1), Row(id: 3)]

    @ViewBuilder
    private func collection(
        _ kind: Kind, rows: [Row], selection: Binding<Int?>, policy: SelectionPolicy,
        action: @escaping @MainActor (Row) -> Void
    ) -> some View {
        switch kind {
        case .list:
            List(rows, selection: selection, selectionPolicy: policy) { Text("\($0.id)") }.onActivate(action)
        case .table:
            Table(rows, selection: selection, selectionPolicy: policy) { TableColumn("ID") { Text("\($0.id)") } }
                .onActivate(action)
        case .outline:
            OutlineGroup(
                rows, children: \.children, selection: selection, expandedIDs: .constant([]),
                selectionPolicy: policy
            ) { Text("\($0.id)") }.onActivate(action)
        }
    }

    @Test("Effective elements activate after committing selection and replace submission")
    func effectiveActivation() {
        // -- Arrange --
        for kind in Kind.allCases {
            for initial in [Int?.none, 99, 3] {
                for policy in [SelectionPolicy.firstVisible, .allowEmpty] {
                    var selection = initial
                    var events: [String] = []
                    var submitted = 0
                    let renderer = ViewRenderer.make(
                        collection(
                            kind, rows: rows,
                            selection: Binding(
                                get: { selection },
                                set: {
                                    selection = $0
                                    events.append("selection:\($0!)")
                                }), policy: policy, action: { events.append("activation:\($0.id)") }
                        )
                        .onSubmit { submitted += 1 })
                    _ = renderer.render(.now)

                    // -- Act --
                    let handled = renderer.handle(.enter)

                    // -- Assert --
                    let effective = policy.resolve(in: rows, selection: initial)
                    #expect(handled && submitted == 0)
                    #expect(events == effective.map { ["selection:\($0.id)", "activation:\($0.id)"] } ?? [])
                }
            }
        }
    }

    @Test("Empty collections consume Enter without activation or selection writes")
    func empty() {
        // -- Arrange --
        for kind in Kind.allCases {
            var calls = 0
            let renderer = ViewRenderer.make(
                collection(
                    kind, rows: [], selection: Binding(get: { 99 }, set: { _ in calls += 1 }),
                    policy: .firstVisible, action: { _ in calls += 1 }
                ).onSubmit { calls += 1 })
            _ = renderer.render(.now)

            // -- Act --
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(calls == 0)
        }
    }

    @Test("Activation receives updated payloads and filtering follows the selection policy")
    func updatedItems() {
        // -- Arrange --
        for kind in Kind.allCases {
            var activated: [Row] = []
            func view(_ data: [Row], policy: SelectionPolicy) -> some View {
                collection(kind, rows: data, selection: .constant(3), policy: policy, action: { activated.append($0) })
            }
            let renderer = ViewRenderer.make(view(rows, policy: .firstVisible))
            _ = renderer.render(.now)

            // -- Act --
            renderer.update(view([Row(id: 3, title: "Updated")], policy: .firstVisible), at: .now)
            _ = renderer.render(.now)
            _ = renderer.handle(.enter)
            renderer.update(view([Row(id: 1)], policy: .allowEmpty), at: .now)
            _ = renderer.render(.now)
            _ = renderer.handle(.enter)
            renderer.update(view([Row(id: 1)], policy: .firstVisible), at: .now)
            _ = renderer.render(.now)
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(activated.map(\.id) == [3, 1])
            #expect(activated.first?.title == "Updated")
        }
    }

    @Test("Outline activation uses visible original elements, not flattened row metadata")
    func hiddenOutline() {
        // -- Arrange --
        let tree = [Row(id: 1, children: [Row(id: 2)])]
        var activated: [Int] = []
        func view(_ expanded: Set<Int>, policy: SelectionPolicy) -> some View {
            OutlineGroup(
                tree, children: \.children, selection: .constant(2), expandedIDs: .constant(expanded),
                selectionPolicy: policy
            ) { Text("\($0.id)") }.onActivate { activated.append($0.id) }
        }
        let renderer = ViewRenderer.make(view([], policy: .allowEmpty))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        renderer.update(view([], policy: .firstVisible), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        renderer.update(view([1], policy: .allowEmpty), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == [1, 2])
    }

    @Test("Activation keeps its effective payload even if the binding setter redirects selection")
    func bindingIndependence() {
        // -- Arrange --
        for kind in Kind.allCases {
            var selection: Int? = 99
            var activated: Int?
            let renderer = ViewRenderer.make(
                collection(
                    kind, rows: rows, selection: Binding(get: { selection }, set: { _ in selection = 3 }),
                    policy: .firstVisible, action: { activated = $0.id }))
            _ = renderer.render(.now)

            // -- Act --
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(activated == 1 && selection == 3)
        }
    }

    @Test("Disabled collections do not activate or fall through to submission")
    func disabled() {
        // -- Arrange --
        for kind in Kind.allCases {
            var calls = 0
            let renderer = ViewRenderer.make(
                collection(
                    kind, rows: rows, selection: .constant(3), policy: .firstVisible,
                    action: { _ in calls += 1 }
                ).disabled(true).onSubmit { calls += 1 })
            _ = renderer.render(.now)

            // -- Act --
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(calls == 0)
        }
    }

    @Test("Modal scopes block underlying activation and restore it after dismissal")
    func modalIsolation() {
        // -- Arrange --
        var presented = true
        var activated = 0
        func view() -> some View {
            collection(
                .list, rows: rows, selection: .constant(3), policy: .firstVisible,
                action: { _ in activated += 1 }
            )
            .sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                Button("Close") { presented = false }
            }
        }
        let renderer = ViewRenderer.make(view())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let blocked = activated
        renderer.update(view(), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(!presented && blocked == 0 && activated == 1)
    }

    @Test("Later callbacks replace earlier ones and can be removed without changing the collection type")
    func replacement() {
        // -- Arrange --
        var first = 0
        var second = 0
        var submitted = 0
        func list() -> List<[Row], Int, Text> {
            List(rows, selection: .constant(3)) { return Text("\($0.id)") }
        }
        let renderer = ViewRenderer.make(
            list().onActivate { _ in first += 1 }.onActivate { _ in second += 1 }.onSubmit { submitted += 1 })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        renderer.update(list().onSubmit { submitted += 1 }, at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(first == 0 && second == 1 && submitted == 1)
    }

    @Test("Sortable headers sort rather than activating the effective row")
    func headers() {
        // -- Arrange --
        var activated = 0
        var sorted = 0
        let renderer = ViewRenderer.make(
            Table(rows, selection: .constant(3), sortOrder: Binding(get: { [] }, set: { _ in sorted += 1 })) {
                TableColumn("ID", value: \.id) { Text("\($0.id)") }
            }.onActivate { _ in activated += 1 })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(sorted == 1 && activated == 1)
    }
}
