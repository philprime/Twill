import Testing

@testable import Twill

@Suite("Payload-driven sheets")
@MainActor
struct ItemSheetTests {
    private struct Payload: Identifiable {
        let id: Int
        let title: String
    }

    private struct Counter: View {
        let item: Payload
        @State private var count = 0
        var body: some View { Button("\(item.title):\(count)") { count += 1 } }
    }

    private struct Fixture: View {
        @State private var item: Payload?
        let capture: (Binding<Payload?>) -> Void
        let action: (String) -> Void
        var body: some View {
            capture($item)
            return HStack {
                Button("A") { action("A") }
                Button("B") { action("B") }
            }.sheet(item: $item) { Counter(item: $0) }
        }
    }

    @Test("Nil skips construction and matching IDs update payload while retaining mounted state")
    func sameIdentity() throws {
        // -- Arrange --
        var item: Binding<Payload?>?
        let renderer = ViewRenderer.make(Fixture(capture: { item = $0 }, action: { _ in }))
        let base = try #require(renderer.render(.now).grid)
        item?.wrappedValue = Payload(id: 1, title: "One")
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        weak var child: ViewRenderer?
        child = renderer.keyedNode(for: 1)

        // -- Act --
        item?.wrappedValue = Payload(id: 1, title: "Updated")
        let updated = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(base.snapshotText == "A B")
        #expect(updated.snapshotText.contains("Updated:1"))
        #expect(child != nil && child === renderer.keyedNode(for: 1))
    }

    @Test("Changed IDs replace state and nil restores the remembered base focus")
    func replacementAndDismissal() throws {
        // -- Arrange --
        var item: Binding<Payload?>?
        var actions: [String] = []
        let renderer = ViewRenderer.make(Fixture(capture: { item = $0 }, action: { actions.append($0) }))
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        item?.wrappedValue = Payload(id: 1, title: "One")
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        weak var old: ViewRenderer?
        old = renderer.keyedNode(for: 1)

        // -- Act --
        item?.wrappedValue = Payload(id: 2, title: "Next")
        let replacement = try #require(renderer.render(.now).grid)
        let released = old == nil
        item?.wrappedValue = nil
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        item?.wrappedValue = Payload(id: 2, title: "Again")
        let reopened = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(released && replacement.snapshotText.contains("Next:0"))
        #expect(actions == ["B"])
        #expect(reopened.snapshotText.contains("Again:0"))
    }

    @Test("No payload means no presented content evaluation")
    func absentPayload() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(
            Text("Base").sheet(item: Binding<Payload?>.constant(nil)) { value in
                evaluations += 1
                return Text(value.title)
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Base" && evaluations == 0)
    }

    @Test("Payload content receives fresh values and resize uses the cached description")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(
            Text("Base").sheet(item: .constant(Payload(id: 1, title: "Payload"))) { value in
                evaluations += 1
                return Text(value.title)
            })
        _ = renderer.render(.now)

        // -- Act --
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 20, height: 7)))

        // -- Assert --
        #expect(resized.size == CellSize(width: 20, height: 7))
        #expect(evaluations == 1)
    }
}
